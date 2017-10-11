#!/usr/bin/python

import subprocess
import requests
import json
from datetime import date, timedelta, datetime

class EsLib:
  """A ES libary to handle es related operation in new architecture"""
  def __init__(self, logger):
    self.logger=logger
    self.esClusters = []
    self.esDiskSize = 0
    self.esDataNodeNumber = 0
    self.esRetentionDays = 0
    self.tenantinfo=self.getTenantInfoIp()
    self.esClusters=self.getEsClusterList()
    self.esRetentionDays = self.getEsRetentionDays()

  def getTenantInfoIp(self):
    with open('/opt/deploy/hosts/multiserver_lb', 'r') as f:
      tiHost = f.readlines()[1:]
    f.close()
    return tiHost[0].strip()

  def populateClusterStats(self, cluster, resc):
    cluster["status"] = resc["status"]
    cluster["nodes.count.data"] = resc["nodes"]["count"]["data"] #total data nodes
    cluster["indices.docs.count"] = resc["indices"]["docs"]["count"]
    cluster["indices.store.size_in_bytes"] = resc["indices"]["store"]["size_in_bytes"]
    cluster["nodes.fs.total_in_bytes"] = resc["nodes"]["fs"]["total_in_bytes"]
    cluster["nodes.fs.total_in_gb"] = resc["nodes"]["fs"]["total_in_bytes"] / 1073741824
    cluster["nodes.fs.free_in_bytes"] = resc["nodes"]["fs"]["free_in_bytes"]
    cluster["nodes.fs.free_in_gb"] = resc["nodes"]["fs"]["free_in_bytes"] / 1073741824
    cluster["nodes.fs.available_in_bytes"] = resc["nodes"]["fs"]["available_in_bytes"]
    cluster["nodes.fs.available_in_gb"] = resc["nodes"]["fs"]["available_in_bytes"] / 1073741824
    cluster["nodes.fs.used_in_bytes"] = cluster["nodes.fs.total_in_bytes"] - cluster["nodes.fs.available_in_bytes"]
    cluster["nodes.fs.used_in_gb"] = cluster["nodes.fs.total_in_gb"] - cluster["nodes.fs.available_in_gb"]

  def populateNodeStats(self, cluster, prefix, res):
    cluster[prefix + "nodes.count.data"] = res["_nodes"]["total"]
    cluster[prefix + "indices.docs.count"] = 0
    cluster[prefix + "indices.store.size_in_bytes"] = 0
    cluster[prefix + "nodes.fs.total_in_bytes"] = 0
    cluster[prefix + "nodes.fs.free_in_bytes"] = 0
    cluster[prefix + "nodes.fs.available_in_bytes"] = 0
    for key, node in res["nodes"].iteritems():
      cluster[prefix + "indices.docs.count"] +=  node["indices"]["docs"]["count"]
      cluster[prefix + "indices.store.size_in_bytes"] += node["indices"]["store"]["size_in_bytes"]
      cluster[prefix + "nodes.fs.total_in_bytes"] += node["fs"]["total"]["total_in_bytes"]
      cluster[prefix + "nodes.fs.free_in_bytes"] += node["fs"]["total"]["free_in_bytes"]
      cluster[prefix + "nodes.fs.available_in_bytes"] += node["fs"]["total"]["available_in_bytes"]
    cluster[prefix + "nodes.fs.total_in_gb"] = cluster[prefix + "nodes.fs.total_in_bytes"] / 1073741824
    cluster[prefix + "nodes.fs.free_in_gb"] = cluster[prefix + "nodes.fs.free_in_bytes"] / 1073741824
    cluster[prefix + "nodes.fs.available_in_gb"] = cluster[prefix + "nodes.fs.available_in_bytes"] / 1073741824
    cluster[prefix + "nodes.fs.used_in_bytes"] = cluster[prefix + "nodes.fs.total_in_bytes"] - cluster[prefix + "nodes.fs.available_in_bytes"]
    cluster[prefix + "nodes.fs.used_in_gb"] = cluster[prefix + "nodes.fs.total_in_gb"] - cluster[prefix + "nodes.fs.available_in_gb"]
    cluster[prefix + "fragment.ratio"] = float(cluster["nodes.fs.used_in_bytes"]) / cluster[prefix + "indices.store.size_in_bytes"]

  # get last 12 hours max thoughput per 30 minutes.
  def getClusterThroughPut(self, cluster):
    today = date.today()
    yesterday = today - timedelta(1)
    end = datetime.now()
    td = timedelta(0, 1800)
    avg_rate = -1.0
    max_rate = -1.0
    for i in range (0, 24):
        start = end - td
        endstr = end.strftime("%s")+"000"
        startstr = start.strftime("%s")+"000"
        query = '{"query":{"bool": {"must":{"range": {"@timestamp": {"gte":' + startstr + ',"lte":' + endstr + ',"format": "epoch_millis"}}}}}}'
        r = requests.post("http://" + cluster["cluster.vip"] + ":9200/" + today.strftime("logstash-%Y.%m.%d") + "," + yesterday.strftime("logstash-%Y.%m.%d") + "/_count", data=query)
        res = r.json()
        if "count" in res:
            rate=float(res["count"])/1800/1024
            if rate > max_rate:
                max_rate = rate
        end=start
    query = '{"query":{"bool": {"must":{"range": {"@timestamp": {"gte":' + yesterday.strftime("%s")+"000" + ',"lte":' +  today.strftime("%s")+"000" + ',"format": "epoch_millis"}}}}}}'
    r = requests.post("http://" + cluster["cluster.vip"] + ":9200/" + today.strftime("logstash-%Y.%m.%d") + "," + yesterday.strftime("logstash-%Y.%m.%d") + "/_count", data=query)
    res = r.json()
    if "count" in res:
        avg_rate = float(res["count"])/24/60/60/1024
    return avg_rate, max_rate

  # get last 12 hours max thoughput per 30 minutes.
  def getTenantThroughPut(self, cluster, space_id):
    today = date.today()
    yesterday = today - timedelta(1)
    end = datetime.now()
    td = timedelta(0, 1800)
    avg_rate = -1.0
    max_rate = -1.0
    for i in range (0, 24):
        start = end - td
        endstr = end.strftime("%s")+"000"
        startstr = start.strftime("%s")+"000"
        query = '{"query":{"bool": {"must":{"term":{"ALCH_TENANT_ID": "' + space_id + '"}},' + '"must":{"range": {"@timestamp": {"gte":' + startstr + ',"lte":' + endstr + ',"format": "epoch_millis"}}}}}}'
        r = requests.post("http://" + cluster["cluster.vip"] + ":9200/" + today.strftime("logstash-%Y.%m.%d") + "," + yesterday.strftime("logstash-%Y.%m.%d") + "/_count", data=query)
        res = r.json()
        if "count" in res:
            rate=float(res["count"])/1800/1024
            if rate > max_rate:
                max_rate = rate
        end=start
    query = '{"query":{"bool": {"must":{"term":{"ALCH_TENANT_ID": "' + space_id + '"}},' + '"must":{"range": {"@timestamp": {"gte":' + yesterday.strftime("%s")+"000" + ',"lte":' +  today.strftime("%s")+"000" + ',"format": "epoch_millis"}}}}}}'
    r = requests.post("http://" + cluster["cluster.vip"] + ":9200/" + today.strftime("logstash-%Y.%m.%d") + "," + yesterday.strftime("logstash-%Y.%m.%d") + "/_count", data=query)
    res = r.json()
    if "count" in res:
        avg_rate = float(res["count"])/24/60/60/1024
    return avg_rate, max_rate

  def populateCluster(self, cluster):
    today = date.today()
    rc = requests.get("http://" + cluster["cluster.vip"] + ":9200/_cluster/stats")
    resc = rc.json()
    self.populateClusterStats(cluster, resc)
    rc = requests.get("http://" + cluster["cluster.vip"] + ":9200/_nodes/*hot/stats/indices,fs")
    reshot = rc.json()
    self.populateNodeStats(cluster, "hot.", reshot)
    rc = requests.get("http://" + cluster["cluster.vip"] + ":9200/_nodes/*warm/stats/indices,fs")
    reswarm = rc.json()
    self.populateNodeStats(cluster, "warm.", reshot)
    cluster["indices"] = []
    for d in range(0, 3):
      day = today - timedelta(d)
      index_name = day.strftime("logstash-%Y.%m.%d")
      req = requests.get("http://" + cluster["cluster.vip"] + ":9200/" + index_name + "/_stats")
      res = req.json()
      index = {}
      index["name"] = index_name
      if "error" in res:
        index["shards"] = -1
        index["total_in_gb"] = -1
        index["docs"] = -1
      else:
        index["shards"] = res["_shards"]["total"]
        index["size_in_gb"] = res["indices"][index_name]["total"]["store"]["size_in_bytes"] / 1073741824
        index["docs"] = res["indices"][index_name]["total"]["docs"]["count"]
      cluster["indices"].append(index)
    cluster["throughput.avg"], cluster["throughput.max"] = self.getClusterThroughPut(cluster)
    cluster["max.per.day.quota.available.tb"]= float(cluster["hot.nodes.fs.available_in_bytes"]) / cluster["hot.fragment.ratio"] / 2 / self.getEsRetentionDays() / 1073741824 / 1024

  def getEsClusterList(self):
    if len(self.esClusters) > 0:
      return self.esClusters
    myList=[]
    r = requests.get("https://" + self.tenantinfo + ":9099/es_shard/list", verify=False)
    res = r.json()
    shards = res["shards"]
    num_shards = len(shards)
    for item in shards:
      cluster = {}
      cluster["enabled"] = item["status"]
      cluster["cluster.name"] = item["cluster"]["name"]
      cluster["cluster.vip"] = item["cluster"]["vip"]
      cluster["topic"] = item["topic"]
      myList.append(cluster)
    return myList

  def toHuman(self, sz):
    if sz > 1073741824 * 1024:
      return "%dT" % (sz / 1073741824 / 1024)
    if sz > 1073741824:
      return "%dG" % (sz / 1073741824)
    if sz > 1048576:
      return "%dM" % (sz / 1048576)
    if sz > 1024:
      return "%dK" % (sz / 1024)
    return "%d" % sz

  def printEsClusterStatus(self, clusters):
     today = date.today()
     print ''
     print '----------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
     print '|                                                                                      |   %20.20s    |   %20.20s    |   %20.20s    |' % ((today - timedelta(0)).strftime("logstash-%Y.%m.%d"),
      (today - timedelta(1)).strftime("logstash-%Y.%m.%d"),(today - timedelta(2)).strftime("logstash-%Y.%m.%d"))
     print '|      Name       ENA STA HND WND   HTOT   HUSE   HAVL HUSE% FRAG   MPQA  A.TPT  M.TPT | SHRD   DOCS    AVG   SIZE | SHRD   DOCS    AVG   SIZE | SHRD   DOCS    AVG   SIZE |'
     for cluster in clusters:
         print '----------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
         hotused = cluster["hot.nodes.fs.used_in_gb"] * 100 / cluster["hot.nodes.fs.total_in_gb"]
         print '|%-16s %.3s %.3s %3d %3d %5.1fT %5.1fT %5.1fT %4d%% %4.2f %5.2fT %5.2fK %5.2fK | %4d  %5.5s %5.2fG %5.2fT | %4d  %5.5s %5.2fG %5.2fT | %4d  %5.5s %5.2fG %5.2fT |' % (cluster["cluster.name"], cluster["enabled"].upper(), cluster["status"].upper(),
            cluster["hot.nodes.count.data"], cluster["warm.nodes.count.data"],
            float(cluster["hot.nodes.fs.total_in_gb"])/1024, float(cluster["hot.nodes.fs.used_in_gb"])/1024, float(cluster["hot.nodes.fs.available_in_gb"]) / 1024, hotused, cluster["hot.fragment.ratio"], cluster["max.per.day.quota.available.tb"], cluster["throughput.avg"], cluster["throughput.max"],
            cluster["indices"][0]["shards"], self.toHuman(cluster["indices"][0]["docs"]), float(cluster["indices"][0]["size_in_gb"])/cluster["indices"][0]["shards"], float(cluster["indices"][0]["size_in_gb"])/1024.0,
            cluster["indices"][1]["shards"], self.toHuman(cluster["indices"][1]["docs"]), float(cluster["indices"][1]["size_in_gb"])/cluster["indices"][1]["shards"], float(cluster["indices"][1]["size_in_gb"])/1024.0,
            cluster["indices"][2]["shards"], self.toHuman(cluster["indices"][2]["docs"]), float(cluster["indices"][2]["size_in_gb"])/cluster["indices"][2]["shards"], float(cluster["indices"][2]["size_in_gb"])/1024.0
            )
     print '----------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
     print 'LABELS:'
     print '\tENA:  Enabled for tenant assignment or not.                STA:  Cluster status.'
     print '\tHND:  Hot Data Node number.                                WND:  Warm data node number.'
     print '\tHTOT: Hot data node total storage.                         HUSE: Hot data node used storage(P+R).'
     print '\tHAVL: Hot data node available storage.                     HUSE: Hot data node storage used percent.'
     print '\tFRAG: Fragment ratio (doc size / disk sspace used.)        ATPT: Average ingestion through put in last 12 hours'
     print '\tMTPT: Max ingestion through put in last 12 hours.          SHRD: Index shard total number (P+R).'
     print '\tDOCS: Index total document count.                          AVG:  Average shard size.'
     print '\tSIZE: Total index storage used (P+R).                      MPQA: Max quota avaiable per day in TB'
     print '\n\n'

  def getEsRetentionDays(self):
    if self.esRetentionDays > 1:
      return self.esRetentionDays
    cmd1 = "grep ^retention_time /opt/deploy/group_vars/es_retention | awk '{print $2}'"
    result1 = subprocess.check_output(cmd1, shell=True,stderr=subprocess.STDOUT)
    retention_seconds = int(result1.strip())
    return retention_seconds / 86400

  #return tenant quota in MB
  def getTenantQuotaInMB(self, spaceId):
    r = requests.get("https://" + self.tenantinfo + ":9099/quota/getusage?space-id=" + spaceId, verify=False)
    res = r.json()
    quota = res["usage"]["dailyallotment"]
    return int(quota)/1048576

  #return average usage in last a couple of days
  def getTenantAvgUsageInMB(self, spaceId):
    r = requests.get("https://" + self.tenantinfo + ":9099/quota/getusagehistory?space-id=" + spaceId, verify=False)
    res = r.json()
    allowed = self.getTenantQuotaInMB(spaceId)
    history = res["History"]
    if history is not None:
      usage = 0
      days = 0
      for k, v in history.iteritems():
        u = int(v)/1048576
        if u > allowed:
          u = allowed
        usage = usage + u
        days = days + 1
      return usage/days
    return 0

  def getTenantAvgDocSizeInByte(self, cluster, spaceId):
    r = requests.get("https://" + self.tenantinfo + ":9099/quota/getusagehistory?space-id=" + spaceId, verify=False)
    res = r.json()
    allowed = self.getTenantQuotaInMB(spaceId)
    history = res["History"]
    if history is not None:
      usage = long(0)
      docs = long(0)
      for k, v in history.iteritems():
        u = long(v)
        if u > allowed:
          u = allowed * 1024 * 1024
        query = '{"query":{"bool": {"must":{"term":{"ALCH_TENANT_ID": "' + spaceId + '"}}}}}'
        r = requests.post("http://" + cluster["cluster.vip"] + ":9200/logstash-" + k + "/_count", data=query)
        res = r.json()
        if "count" in res:
            usage = usage + u
            docs = docs + res["count"]
      if docs > 0:
        return usage / docs
    return 0


  def getTenantEstimate(self, spaceId, requestGB):
    r = requests.get("https://" + self.tenantinfo + ":9099/cluster/get?tenant_id=" + spaceId, verify=False)
    res = r.json()
    estimate = {}
    estimate["space.id"] = spaceId
    estimate["cluster.name"] = res["cluster-number"]
    for cluster in self.esClusters:
      if cluster["cluster.name"] == estimate["cluster.name"]:
        estimate["cluster"] = cluster
    self.populateCluster(estimate["cluster"])
    estimate["quota.current.gb"] = float(self.getTenantQuotaInMB(spaceId)) / 1024.0
    estimate["quota.request.gb"] = float(requestGB)
    estimate["sent.average.gb"] = float(self.getTenantAvgUsageInMB(spaceId)) / 1024.0
    estimate["fs.average.total_in_gb"] = float(estimate["sent.average.gb"]) * 2 * self.getEsRetentionDays() * estimate["cluster"]["hot.fragment.ratio"]
    estimate["fs.request.total_in_gb"] = float(requestGB) * 2 * self.getEsRetentionDays() * estimate["cluster"]["hot.fragment.ratio"]
    estimate["throughput.current.avg"], estimate["throughput.current.max"] = self.getTenantThroughPut(estimate["cluster"], spaceId)
    estimate["doc.size.avg"] = self.getTenantAvgDocSizeInByte(estimate["cluster"], spaceId)
    return estimate

  def printTenantEstimate(self, tenant):
    cluster =  tenant["cluster"]
    hotused = cluster["hot.nodes.fs.used_in_gb"] * 100 / cluster["hot.nodes.fs.total_in_gb"]
    etpt = 0.0
    if tenant["doc.size.avg"] > 0:
        docs = float(tenant["quota.request.gb"]) * 1024*1024*1024 / tenant["doc.size.avg"]
        etpt = docs / 24 / 60 / 60 / 1024
    print '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
    print '|                                     CLUSTER                                          |                         %37s                            |' % tenant["space.id"]
    print '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
    print '|      Name       ENA STA HND WND   HTOT   HUSE   HAVL HUSE% FRAG   MPQA  A.TPT  M.TPT |   C.QT   SENT   FSTOT   u/U%   u/T%  A.TPT  M.TPT |   E.QT   FSTOT   u/U%   u/T%   E.TPT | '
    print '|%-16s %.3s %.3s %3d %3d %5.1fT %5.1fT %5.1fT %4d%% %4.2f %5.2fT %5.2fK %5.2fK | %5.1fG %5.1fG %6.1fG %5.2f%% %5.2f%% %5.2fK %5.2fK | %5.1fG %6.1fG %5.2f%% %5.2f%%  %5.2fK |' % (cluster["cluster.name"], cluster["enabled"].upper(), cluster["status"].upper(),
        cluster["hot.nodes.count.data"], cluster["warm.nodes.count.data"],
        float(cluster["hot.nodes.fs.total_in_gb"])/1024, float(cluster["hot.nodes.fs.used_in_gb"])/1024, float(cluster["hot.nodes.fs.available_in_gb"]) / 1024, hotused, cluster["hot.fragment.ratio"], cluster["max.per.day.quota.available.tb"], cluster["throughput.avg"], cluster["throughput.max"],
        tenant["quota.current.gb"], tenant["sent.average.gb"], tenant["fs.average.total_in_gb"], tenant["fs.average.total_in_gb"] * 100 / cluster["hot.nodes.fs.used_in_gb"], tenant["fs.average.total_in_gb"] * 100 / cluster["hot.nodes.fs.total_in_gb"], tenant["throughput.current.avg"], tenant["throughput.current.max"],
        tenant["quota.request.gb"], tenant["fs.request.total_in_gb"], tenant["fs.request.total_in_gb"] * 100 / cluster["hot.nodes.fs.used_in_gb"], tenant["fs.request.total_in_gb"] * 100 / cluster["hot.nodes.fs.total_in_gb"], etpt
        )
    print '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------'
    print 'LABELS:'
    print '\tENA:  Enabled for tenant assignment or not.                STA:  Cluster status.'
    print '\tHND:  Hot Data Node number.                                WND:  Warm data node number.'
    print '\tHTOT: Hot data node total storage.                         HUSE: Hot data node used storage(P+R).'
    print '\tHAVL: Hot data node available storage.                     HUSE: Hot data node storage used percent.'
    print '\tFRAG: Fragment ratio (doc size / disk sspace used.)        ATPT: Average ingestion through put in last 12 hours'
    print '\tMTPT: Max ingestion through put in last 12 hours.'
    print '\tC.QT: The tenant current quota limit.                      FSTOT:Total ES storage used by tenant (P+R) * retentions * FRAG'
    print '\tu/U%: Total disk used by tenant / total disk used.         u/T%: Total disk used by tenant / total disk'
    print '\tATPT: Avg through put in last 12 hours by tenant.          MTPT: Max through put in last 12 hours by tenant.'
    print '\tE.QT: The quota limit to be estimated.                     FSTOT:Total disk storage going to be used based on E.QT.'
    print '\tETPT: Estimated throughput if E.QT fully consumed.'
    print '\n\n'

