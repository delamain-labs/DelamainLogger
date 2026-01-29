import Testing
import Foundation
@testable import DelamainLogger

@Suite("LogSampler Tests")
struct LogSamplerTests {

    private func makeMessage(level: LogLevel = .info) -> LogMessage {
        LogMessage(level: level, message: "Test", source: "Test")
    }

    // MARK: - Rate Sampling

    @Test("Rate sampling respects probability")
    func rateSamplingWorks() {
        let sampler = SamplingFilter(strategy: .rate(0.5), alwaysLogLevels: [])

        var logged = 0
        let iterations = 1000

        for _ in 0..<iterations {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        // Should be roughly 50% (allow 35-65% for randomness)
        let rate = Double(logged) / Double(iterations)
        #expect(rate > 0.35 && rate < 0.65, "Rate was \(rate)")
    }

    @Test("Rate 0.0 blocks all")
    func rateZeroBlocksAll() {
        let sampler = SamplingFilter(strategy: .rate(0.0), alwaysLogLevels: [])

        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        #expect(logged == 0)
    }

    @Test("Rate 1.0 allows all")
    func rateOneAllowsAll() {
        let sampler = SamplingFilter(strategy: .rate(1.0), alwaysLogLevels: [])

        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        #expect(logged == 100)
    }

    // MARK: - One in N Sampling

    @Test("One in N sampling works")
    func oneInNWorks() {
        let sampler = SamplingFilter(strategy: .oneInN(10), alwaysLogLevels: [])

        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        #expect(logged == 10)
    }

    @Test("One in 1 allows all")
    func oneInOneAllowsAll() {
        let sampler = SamplingFilter(strategy: .oneInN(1), alwaysLogLevels: [])

        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        #expect(logged == 100)
    }

    // MARK: - By Level Sampling

    @Test("By level sampling uses correct rates")
    func byLevelWorks() {
        let sampler = SamplingFilter(
            strategy: .byLevel([
                .debug: 0.0,  // Never log debug
                .info: 1.0    // Always log info
            ]),
            alwaysLogLevels: []
        )

        var debugLogged = 0
        var infoLogged = 0

        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage(level: .debug)) {
                debugLogged += 1
            }
            if sampler.shouldLog(makeMessage(level: .info)) {
                infoLogged += 1
            }
        }

        #expect(debugLogged == 0)
        #expect(infoLogged == 100)
    }

    @Test("Missing levels default to 1.0")
    func missingLevelsDefaultToOne() {
        let sampler = SamplingFilter(
            strategy: .byLevel([.debug: 0.0]),
            alwaysLogLevels: []
        )

        // Warning not in map, should default to 1.0
        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage(level: .warning)) {
                logged += 1
            }
        }

        #expect(logged == 100)
    }

    // MARK: - Always Log Levels

    @Test("Always log levels bypass sampling")
    func alwaysLogLevelsBypassSampling() {
        let sampler = SamplingFilter(
            strategy: .rate(0.0),  // Block everything
            alwaysLogLevels: [.error, .critical]
        )

        #expect(sampler.shouldLog(makeMessage(level: .info)) == false)
        #expect(sampler.shouldLog(makeMessage(level: .error)) == true)
        #expect(sampler.shouldLog(makeMessage(level: .critical)) == true)
    }

    @Test("Default always log levels are error and critical")
    func defaultAlwaysLogLevels() {
        let sampler = SamplingFilter(strategy: .rate(0.0))

        #expect(sampler.shouldLog(makeMessage(level: .debug)) == false)
        #expect(sampler.shouldLog(makeMessage(level: .error)) == true)
        #expect(sampler.shouldLog(makeMessage(level: .critical)) == true)
    }

    // MARK: - No Sampling

    @Test("None strategy allows all")
    func noneAllowsAll() {
        let sampler = SamplingFilter(strategy: .none, alwaysLogLevels: [])

        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        #expect(logged == 100)
    }

    // MARK: - Convenience Constructors

    @Test("Percent convenience works")
    func percentConvenienceWorks() {
        let sampler = SamplingFilter.percent(10)

        var logged = 0
        for _ in 0..<1000 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        // Should be roughly 10% (allow 5-15%)
        let rate = Double(logged) / 1000.0
        #expect(rate > 0.05 && rate < 0.15, "Rate was \(rate)")
    }

    @Test("OneIn convenience works")
    func oneInConvenienceWorks() {
        let sampler = SamplingFilter.oneIn(5)

        var logged = 0
        for _ in 0..<100 {
            if sampler.shouldLog(makeMessage()) {
                logged += 1
            }
        }

        #expect(logged == 20)
    }

    @Test("Production preset has correct rates")
    func productionPresetWorks() {
        let sampler = SamplingFilter.production

        // Error should always be logged
        #expect(sampler.shouldLog(makeMessage(level: .error)) == true)
        #expect(sampler.shouldLog(makeMessage(level: .critical)) == true)
    }

    @Test("Development preset allows all")
    func developmentPresetAllowsAll() {
        let sampler = SamplingFilter.development

        for level in LogLevel.allCases {
            #expect(sampler.shouldLog(makeMessage(level: level)) == true)
        }
    }

    // MARK: - Thread Safety

    @Test("Sampler is thread-safe")
    func isThreadSafe() async {
        let sampler = SamplingFilter.oneIn(10)
        let iterations = 1000

        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    sampler.shouldLog(self.makeMessage()) ? 1 : 0
                }
            }

            var total = 0
            for await count in group {
                total += count
            }

            // Should be exactly 100 (1 in 10)
            #expect(total == 100)
        }
    }
}
