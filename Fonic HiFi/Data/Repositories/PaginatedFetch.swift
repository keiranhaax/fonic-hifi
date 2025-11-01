import Foundation
import SwiftData

struct PaginatedModelResult<Model> {
    let items: [Model]
    let hasMore: Bool
    let totalCount: Int?
}

struct PaginatedModelFetch<Model: PersistentModel> {
    var descriptor: FetchDescriptor<Model>
    var page: Int
    var pageSize: Int
    var includeTotalCount: Bool = false

    func execute(in context: ModelContext) throws -> PaginatedModelResult<Model> {
        let resolvedPage = max(page, 0)
        let resolvedPageSize = max(pageSize, 1)
        var paginatedDescriptor = descriptor
        paginatedDescriptor.fetchOffset = resolvedPage * resolvedPageSize
        paginatedDescriptor.fetchLimit = resolvedPageSize + 1

        let fetched = try context.fetch(paginatedDescriptor)
        let items = Array(fetched.prefix(resolvedPageSize))
        let hasMore = fetched.count > resolvedPageSize

        let totalCount: Int? = if includeTotalCount {
            try context.batchedFetchCount(descriptor.removingPagination())
        } else {
            nil
        }

        return PaginatedModelResult(items: items, hasMore: hasMore, totalCount: totalCount)
    }
}

private extension FetchDescriptor {
    func removingPagination() -> Self {
        var copy = self
        copy.fetchLimit = nil
        copy.fetchOffset = nil
        return copy
    }
}
