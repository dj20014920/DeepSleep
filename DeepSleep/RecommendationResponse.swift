import Foundation

struct RecommendationResponse: Codable {
    let empathy: String
    let fortune: String
    let presetName: String
    let volumes: [Float]
    let prompt: String
}
