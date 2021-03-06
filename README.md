# Enpitsu

A client for [`graphite-api`](https://graphite-api.readthedocs.io), named after the Japanese word for pencil. This can also be used through Grafana if that is configured to pass through to Graphite as a datasource.

If there are dashboards configured in Grafana, one can also use this library to get a list of dashboards as well as the graphs on a dashboard.

## Usage

```swift
import Foundation

let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .medium
dateFormatter.timeStyle = .medium
dateFormatter.timeZone = TimeZone(abbreviation: "PDT")!

let client = Enpitsu(graphiteServer: "http://graphite.example.com:9001")
let metrics = try client.retrieveMetrics("collectd.*.servers.host-*.metricname")
for timeseries in metrics {
    print("Target: \(timeseries.target)")
    for datapoint in timeseries.datapoints {
        print(incidentDateFormatter.string(from: datapoint.date))
        print("\(value)")
    }
}
```
