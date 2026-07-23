import Foundation

struct APIErrorResponse: Codable {
    let error: APIErrorDetail?

    struct APIErrorDetail: Codable {
        let message: String?
        let type: String?
        let code: String?
    }
}

struct APIStatusResponse: Codable {
    let status: String?
    let message: String?
}

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]?
    let total: Int?
    let page: Int?
    let pageSize: Int?

    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
}
