//
//  Model.swift
//
//
//  Created by Joe Smith on 6/29/19.
//

import Foundation

public extension Enpitsu {
    enum TimeseriesResponse {
        case graphite([Timeseries])
        case prometheus(PrometheusResponse)
    }
}

public extension Enpitsu {
    enum GraphiteDate {
        case string(String)
        case date(Date)
    }

    struct DashboardResponse: Decodable {
        public struct Meta: Decodable {
            public let type: String
            public let createdBy: String
            public let updatedBy: String
            public let version: Int
            public let slug: String
            public let url: String
        }

        public let dashboard: Dashboard
        public let meta: Meta
    }

    struct Dashboard: Decodable {
        public struct Panel: Decodable {
            public enum PanelType: String, Decodable {
                case row, graph, table, singlestat
            }

            public struct Target: Decodable {
                public let type: String?
                public let target: String? // The important part!
                public let expr: String? // The query can also be here
            }

            public let type: PanelType
            public let description: String?
            //TODO: let thresholds =
            public let title: String
            public let targets: [Target]?
            public let datasource: String?
        }

        public let id: Int
        public let uid: String
        public let title: String
        public let url: String?
        public let type: String?
        public let tags: [String]
        public let isStarred: Bool?
        public let panels: [Panel]?
        public let templating: Templates?
    }

    struct Templates: Decodable {
        public struct Template: Decodable {
            public let allFormat: AllFormat?
            public let allValue: String?
            public let current: CurrentValue
            public let datasource: String?
            public let name: String
            public let query: String
        }

        public enum AllFormat: String, Decodable {
            case glob
        }

        public struct CurrentValue: Decodable {
            public let text: String
            public let value: String?
            public let values: [String]?

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                text = try container.decode(String.self, forKey: .text)
                do {
                    value = try container.decode(String.self, forKey: .value)
                    values = nil
                } catch {
                    values = try container.decode([String].self, forKey: .value)
                    value = nil
                }
            }

            enum CodingKeys: String, CodingKey {
                case text, value
            }
        }

        public let list: [Template]
    }

    struct Timeseries: Decodable {
        public struct Datapoint: Decodable {
            public let date: Date
            public let value: Double?

            public init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                value = try container.decodeIfPresent(Double.self)
                let timestamp = try container.decode(Int.self)
                date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
        }

        public let target: String
        public let datapoints: [Datapoint]
    }
}

// Prometheus Response
public extension Enpitsu {
    struct PrometheusResponse: Decodable {
        public let status: Status
        public let data: ResponseData
    }

    enum Status: String, Decodable {
        case success
    }

    struct ResponseData: Decodable {
        public let resultType: ResultType
        public let result: [MatrixResult]
    }

    enum ResultType: String, Decodable {
        // case vector // Need to use the VectorResult below that's been commented out
        case matrix
    }

    struct MatrixResult: Decodable {
        public let metric: [String: String]
        public let values: [[Date: Double]]

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            metric = try container.decode([String: String].self, forKey: .metric)
            var valueContainer = try container.nestedUnkeyedContainer(forKey: .values)
            var valuesList = [[Date: Double]]()
            while !valueContainer.isAtEnd {
                var instantValue = try valueContainer.nestedUnkeyedContainer()
                let timestamp = try Date(timeIntervalSince1970: instantValue.decode(Double.self))
                let dataPoint = try Double(instantValue.decode(String.self))!
                valuesList.append([timestamp: dataPoint])
            }
            values = valuesList
        }

        enum CodingKeys: String, CodingKey {
            case metric, values
        }
    }

    /*struct VectorResult: Decodable {
        public let metric: Metric
        public let value: [Date: String]

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            metric = try container.decode(Metric.self, forKey: .metric)
            var valueContainer = try container.nestedUnkeyedContainer(forKey: .value)
            let timestamp = try Date(timeIntervalSince1970: valueContainer.decode(Double.self))
            let dataPoint = try valueContainer.decode(String.self)
            value = [timestamp: dataPoint]
        }

        enum CodingKeys: String, CodingKey {
            case metric, value
        }
    }*/

    // This is likely per-installation
    struct Metric: Decodable {
        public let name: String?
        public let region: Region?
        public let instance: String
        public let job: Job?
        public let provider: Provider?

        enum CodingKeys: String, CodingKey {
            case name = "__name__"
            case region = "_region"
            case instance, job, provider
        }
    }

    enum Region: String, Decodable {
        case usEast1 = "us-east-1"
    }

    enum Job: String, Decodable {
        case node
    }

    enum Provider: String, Decodable {
        case aws
    }
}

