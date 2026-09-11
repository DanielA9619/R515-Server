#!/usr/bin/env bash
set -euo pipefail
[ "${EUID:-$(id -u)}" -eq 0 ] || { echo "Run as root."; exit 1; }

GRAFANA_DIR=/srv/docker/monitoring/grafana
DASH_FILE="$GRAFANA_DIR/dashboards/r515-control-plane.json"
ENV_FILE="$GRAFANA_DIR/.env"
GRAFANA_URL=http://192.168.10.135:3003
PROM_URL=http://192.168.10.135:9090

curl -fsS "$GRAFANA_URL/api/health" >/dev/null
curl -fsS "$PROM_URL/-/ready" >/dev/null
mkdir -p "$(dirname "$DASH_FILE")"

python3 - "$DASH_FILE" <<'PY'
import json, sys
out=sys.argv[1]
ds={"type":"prometheus","uid":"prometheus"}

def stat(i,title,expr,x,y,unit="none",status=False):
    defaults={"unit":unit}
    if status:
        defaults.update({
            "mappings":[{"type":"value","options":{"0":{"text":"DOWN","color":"red"},"1":{"text":"UP","color":"green"}}}],
            "thresholds":{"mode":"absolute","steps":[{"color":"red","value":None},{"color":"green","value":1}]},
            "color":{"mode":"thresholds"}
        })
    elif unit=="percent":
        defaults.update({
            "thresholds":{"mode":"absolute","steps":[{"color":"green","value":None},{"color":"orange","value":75},{"color":"red","value":90}]},
            "color":{"mode":"thresholds"},"decimals":1
        })
    return {
        "id":i,"type":"stat","title":title,"datasource":ds,
        "gridPos":{"h":4,"w":6,"x":x,"y":y},
        "fieldConfig":{"defaults":defaults,"overrides":[]},
        "options":{"colorMode":"background","graphMode":"none","reduceOptions":{"calcs":["lastNotNull"],"fields":"","values":False}},
        "targets":[{"datasource":ds,"expr":expr,"instant":True,"refId":"A"}]
    }

def graph(i,title,queries,x,y,w=8,unit="short",maxv=None):
    defaults={"unit":unit}
    if maxv is not None: defaults.update({"min":0,"max":maxv})
    targets=[]
    for n,(expr,legend) in enumerate(queries):
        targets.append({"datasource":ds,"expr":expr,"legendFormat":legend,"refId":chr(65+n)})
    return {
        "id":i,"type":"timeseries","title":title,"datasource":ds,
        "gridPos":{"h":8,"w":w,"x":x,"y":y},
        "fieldConfig":{"defaults":defaults,"overrides":[]},
        "options":{"legend":{"displayMode":"table","placement":"bottom","calcs":["lastNotNull"]}},
        "targets":targets
    }

panels=[
 stat(1,"Prometheus",'up{job="prometheus"}',0,0,status=True),
 stat(2,"node_exporter",'up{job="docker01"}',6,0,status=True),
 stat(3,"cAdvisor",'up{job="cadvisor"}',12,0,status=True),
 stat(4,"Storage Mount",'clamp_max(count(node_filesystem_size_bytes{job="docker01",mountpoint="/mnt/storage"}),1)',18,0,status=True),
 stat(5,"CPU Usage",'100-(avg(rate(node_cpu_seconds_total{job="docker01",mode="idle"}[5m]))*100)',0,4,"percent"),
 stat(6,"RAM Usage",'100*(1-(node_memory_MemAvailable_bytes{job="docker01"}/node_memory_MemTotal_bytes{job="docker01"}))',6,4,"percent"),
 stat(7,"Storage Used",'100*(1-(node_filesystem_avail_bytes{job="docker01",mountpoint="/mnt/storage"}/node_filesystem_size_bytes{job="docker01",mountpoint="/mnt/storage"}))',12,4,"percent"),
 stat(8,"Storage Free",'node_filesystem_avail_bytes{job="docker01",mountpoint="/mnt/storage"}',18,4,"bytes"),
 graph(9,"CPU Usage",[('100-(avg(rate(node_cpu_seconds_total{job="docker01",mode="idle"}[5m]))*100)',"CPU")],0,8,8,"percent",100),
 graph(10,"RAM Usage",[('100*(1-(node_memory_MemAvailable_bytes{job="docker01"}/node_memory_MemTotal_bytes{job="docker01"}))',"RAM")],8,8,8,"percent",100),
 graph(11,"Network Throughput",[
   ('sum(rate(node_network_receive_bytes_total{job="docker01",device!~"lo|veth.*|br-.*|docker.*"}[5m]))',"RX"),
   ('sum(rate(node_network_transmit_bytes_total{job="docker01",device!~"lo|veth.*|br-.*|docker.*"}[5m]))',"TX")
 ],16,8,8,"Bps"),
 graph(12,"Top Containers - CPU (% host)",[('topk(10,100*sum by(name)(rate(container_cpu_usage_seconds_total{job="cadvisor",image!="",name!=""}[5m]))/scalar(max(machine_cpu_cores{job="cadvisor"})))',"{{name}}")],0,16,12,"percent",100),
 graph(13,"Top Containers - Memory",[('topk(10,sum by(name)(container_memory_working_set_bytes{job="cadvisor",image!="",name!=""}))',"{{name}}")],12,16,12,"bytes")
]

d={
 "id":None,"uid":"r515-control-plane","title":"R515 Control Plane","tags":["r515","homelab","observability"],
 "timezone":"browser","editable":True,"graphTooltip":1,"panels":panels,"refresh":"15s","schemaVersion":41,"version":1,
 "time":{"from":"now-6h","to":"now"},"timepicker":{"refresh_intervals":["5s","15s","30s","1m","5m"]},
 "templating":{"list":[]},"annotations":{"list":[]},"links":[]
}
with open(out,"w") as f: json.dump(d,f,indent=2); f.write("\n")
PY

python3 -m json.tool "$DASH_FILE" >/dev/null
chmod 0644 "$DASH_FILE"
echo "PASS: dashboard JSON written."

USER=$(awk -F= '$1=="GF_SECURITY_ADMIN_USER"{print substr($0,index($0,"=")+1);exit}' "$ENV_FILE")
PASS=$(awk -F= '$1=="GF_SECURITY_ADMIN_PASSWORD"{print substr($0,index($0,"=")+1);exit}' "$ENV_FILE")

for i in $(seq 1 45); do
  if curl -fsS -u "$USER:$PASS" "$GRAFANA_URL/api/search?query=R515%20Control%20Plane" | grep -q 'r515-control-plane'; then
    unset PASS
    echo "PASS: dashboard provisioned."
    echo "Open: https://grafana.r515.allenfamhouse.com/d/r515-control-plane/r515-control-plane"
    exit 0
  fi
  sleep 2
done

unset PASS
echo "ERROR: dashboard was not provisioned."
docker logs --tail=120 grafana || true
exit 1
