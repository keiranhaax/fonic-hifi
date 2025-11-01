@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class SwiftDataPaginationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let schema = Schema([
            RecentSearch.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext

        try seedSearches(count: 40)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        try super.tearDownWithError()
    }

    func testPaginatedFetchDescriptorReturnsCorrectPages() throws {
        var descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = nil
        descriptor.fetchOffset = nil

        let paginator = PaginatedFetchDescriptor(descriptor: descriptor, pageSize: 10)

        let firstPage = try context.fetch(paginator.page(0))
        XCTAssertEqual(firstPage.count, 10)
        XCTAssertEqual(firstPage.first?.query, "query-39")
        XCTAssertEqual(firstPage.last?.query, "query-30")

        let thirdPage = try context.fetch(paginator.page(2))
        XCTAssertEqual(thirdPage.count, 10)
        XCTAssertEqual(thirdPage.first?.query, "query-19")
        XCTAssertEqual(thirdPage.last?.query, "query-10")

        let totalCount = try paginator.count(in: context)
        XCTAssertEqual(totalCount, 40)
    }

    func testFetchCountTraversesAllBatches() throws {
        let descriptor = FetchDescriptor<RecentSearch>()
        let count = try context.batchedFetchCount(descriptor)
        XCTAssertEqual(count, 40)
    }

    func testBatchProcessorProcessesEachBatchExactlyOnce() throws {
        var descriptor = FetchDescriptor<RecentSearch>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = nil
        descriptor.fetchOffset = nil

        let processor = BatchProcessor<RecentSearch>(context: context, batchSize: 12)
        var processedBatches: [[String]] = []

        try processor.processBatches(descriptor: descriptor) { batch in
            processedBatches.append(batch.map(\.query))
        }

        XCTAssertEqual(processedBatches.count, 4)
        XCTAssertEqual(processedBatches.first?.count, 12)
        XCTAssertEqual(processedBatches.last?.count, 4)
        XCTAssertEqual(processedBatches.joined().count, 40)
    }

    private func seedSearches(count: Int) throws {
        let baseDate = Date()
        for index in 0..<count {
            let search = RecentSearch(
                query: "query-\(index)",
                timestamp: baseDate.addingTimeInterval(Double(index)),
                resultCount: index
            )
            context.insert(search)
        }
        try context.save()
    }
}
