# Enpitsu

A client for [`graphite-api`](https://graphite-api.readthedocs.io), named after the Japanese word for pencil.

Example usage:

```swift
import Foundation

let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .medium
dateFormatter.timeStyle = .medium
dateFormatter.timeZone = TimeZone(abbreviation: "PDT")!

let client = Enpitsu(graphiteServer: "http://graphite.example.com:9001")
if let metrics = client.retrieveMetrics("collectd.*.servers.host-*.metricname") {
    for timeseries in metrics {
        print("Target: \(timeseries.target)")
        print("Values:")
        for (date, value) in timeseries.datapoints {
            print("\(dateFormatter.string(from: date)): \(value)")
        }
    }
}
```
