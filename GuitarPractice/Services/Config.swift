import Foundation

enum Config {
    enum Notion {
        // Data source IDs (collection IDs) - used for querying
        enum DataSources {
            static let practiceLibrary = "2d709433-8b1b-804c-897c-000b76c9e481"
            static let practiceSessions = "f4658dc0-2eb2-43fe-b268-1bba231c0156"
            static let practiceLogs = "2d709433-8b1b-809b-bae2-000b1343e18f"
        }

        // Database IDs (from URLs) - used for creating pages
        enum Databases {
            static let practiceLibrary = "2d7094338b1b80ea8a42f746682bf965"
            static let practiceSessions = "7c39d1ff5e2e4458be4c5cded1bc485d"
            static let practiceLogs = "2d7094338b1b80bf9e69fd78ecf57f44"
        }

        // Template IDs
        enum Templates {
            static let practiceSession = "2d7094338b1b8030a56fcca068c6f46c"
        }

        static let apiVersion = "2022-06-28"
        static let baseURL = "https://api.notion.com/v1"
    }

    enum Keychain {
        static let service = "com.sohara.GuitarPractice"
        static let apiKeyAccount = "notion-api-key"
    }
}
