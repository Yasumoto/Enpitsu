import Dispatch
import Foundation

enum GraphiteError: Swift.Error {
        case urlFormattingError
}

struct Timeseries {
    let target: String
    let datapoints: [(Date, Double?)]
}

public struct Enpitsu {
    let graphiteServer: String
    let metrics_index = "/metrics/index.json"
    let query = "/render?format=json&target="
    let sema = DispatchSemaphore(value: 0)

    public init() {}

    public func retrieveMetrics(_ metric: String, from: String = "-10min", until: String = "now") -> [Timeseries]? {
        var series = [Timeseries]()
        guard let endpoint = "\(query)\(metric)&from=\(from)&now=\(until)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { print("Unable to format URL!"); return nil }
        if let serverUrl = URL(string: "\(graphiteServer)\(endpoint)") {
            let session = URLSession(configuration: URLSessionConfiguration.default)
            var request = URLRequest(url: serverUrl)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let task = session.dataTask(with: request) {
                if let responded = $1 as? HTTPURLResponse {
                    if responded.statusCode != 200 {
                        print("The response was: \(responded)")
                    }
                }
                if let responseError = $2 {
                    print("Error: \(responseError)")
                    print("Code: \(responseError._code)")
                } else if let data = $0 {
                    do {
                        if let output = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [[String: Any]] {
                            var metrics = [(Date, Double?)]()
                            for timeseries in output {
                                if let target = timeseries["target"] as? String {
                                    if let datapoints = timeseries["datapoints"] as? [[Any]] {
                                        for datapoint in datapoints {
                                            if let timestamp = datapoint[1] as? Int {
                                                var value: Double? = nil
                                                if let tempValue = datapoint[0] as? Double {
                                                    value = tempValue
                                                }
                                                if let tempValue = datapoint[0] as? Int {
                                                    value = Double(tempValue)
                                                }

                                                let date = Date(timeIntervalSince1970: Double(timestamp))
                                                metrics.append((date, value))
                                            }
                                        }
                                    }
                                    series.append(Timeseries(target: target, datapoints: metrics))
                                }
                            }
                        }
                    } catch {
                        print("Warning, did not receive valid JSON!\n\(error)")
                    }
                }
                self.sema.signal()
            }
            task.resume()
            sema.wait()
        }
        return series
    }
}
