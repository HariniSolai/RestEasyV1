import Foundation

/// Hardcoded resting spots for the UIC / West Loop area.
///
/// ## How to add your own spot
/// 1. Copy one of the `RestingSpot(...)` blocks below and paste it inside the `spots` array.
/// 2. Fill in `name`, `address`, `directions`, coordinates, and `features`.
/// 3. (Optional) Add a photo in Assets.xcassets, then set `imageName` to that asset's name.
/// 4. Build and run — the new pin appears on the map automatically.
///
/// Tip: Find latitude/longitude by dropping a pin in Apple Maps, then choosing
/// "Copy" on the coordinates, or by searching the address on Google Maps.
enum SeedSpots {

    /// Stable IDs so sample reviews stay linked across app launches.
    /// Every spot needs its own unique ID — duplicates won't show on the map.
    enum IDs {
        static let maryBartelmePark = UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!
        static let uicEastCampusQuad = UUID(uuidString: "A1000001-0000-4000-8000-000000000002")!
        static let unionParkBenches = UUID(uuidString: "A1000001-0000-4000-8000-000000000003")!
        static let uicArcBench = UUID(uuidString: "A1000001-0000-4000-8000-000000000004")!
        static let uicBlueLineBridgeBench = UUID(uuidString: "A1000001-0000-4000-8000-000000000005")!
        static let uicArcCrosswalkBenches = UUID(uuidString: "A1000001-0000-4000-8000-000000000006")!
        static let uicPathBench1 = UUID(uuidString: "A1000001-0000-4000-8000-000000000007")!
        static let uicPathBench2 = UUID(uuidString: "A1000001-0000-4000-8000-000000000008")!
        static let uicPathBench3 = UUID(uuidString: "A1000001-0000-4000-8000-000000000009")!
    }

    /// All seed resting spots shown when the app launches.
    /// - Returns: An array of hardcoded `RestingSpot` values.
    static var spots: [RestingSpot] {
        [
            // MARK: - Example: Mary Bartelme Park (West Loop)
            // Photo: add `spot-mary-bartelme` to Assets.xcassets, or leave imageName nil.
            RestingSpot(
                id: IDs.maryBartelmePark,
                name: "Mary Bartelme Park",
                address: "115 S Sangamon St, Chicago, IL 60607",
                directions: "Quiet West Loop park with benches under trees near the playground.",
                latitude: 41.8796,
                longitude: -87.6510,
                features: [.bench, .park, .shadedLocation, .seating],
                imageName: "spot-mary-bartelme",
                averageRating: 4.6,
                reviewCount: 9
            ),

            // MARK: - UIC East Campus Quad
            RestingSpot(
                id: IDs.uicEastCampusQuad,
                name: "UIC East Campus Quad",
                address: "750 S Halsted St, Chicago, IL 60607",
                directions: "Open lawn seating between lecture halls; look for shaded benches along the walkways.",
                latitude: 41.8719,
                longitude: -87.6476,
                features: [.bench, .shadedLocation, .seating, .accessible],
                imageName: nil,
                averageRating: 4.2,
                reviewCount: 14
            ),

            // MARK: - Union Park
            RestingSpot(
                id: IDs.unionParkBenches,
                name: "Union Park Benches",
                address: "1501 W Randolph St, Chicago, IL 60607",
                directions: "Park benches near the Randolph Street entrance; good shade in the afternoon.",
                latitude: 41.8843,
                longitude: -87.6650,
                features: [.bench, .park, .shadedLocation, .waterFountain],
                imageName: nil,
                averageRating: 4.4,
                reviewCount: 6
            ),
            // MARK: - UIC East Campus Spots
            RestingSpot(
                id: IDs.uicArcBench,
                name: "UIC ARC Bench",
                address: "940 W Harrison St, Chicago, IL 60607",
                directions: "Seating areas in front of the Starbucks in the UIC ARC Building",
                latitude: 41.874585,
                longitude: -87.650228,
                features: [.bench],
                imageName: nil,
                averageRating: 0,
                reviewCount: 0
            ),
            RestingSpot(
                id: IDs.uicBlueLineBridgeBench,
                name: "Bench on Bridge near UIC Blue Line",
                address: "940 W Harrison St, Chicago, IL 60607",
                directions: "Place to sit as you get on the bridge to the UIC-Blue line station",
                latitude: 41.874693,
                longitude: -87.649724,
                features: [.bench, .shadedLocation, .accessible, .seating],
                imageName: nil,
                averageRating: 0,
                reviewCount: 0
            ),
            RestingSpot(
                id: IDs.uicArcCrosswalkBenches,
                name: "Benches",
                address: "Near Crosswalk/signal from UIC campus to UIC ARC",
                directions: "Place to sit at right near the road next to the Student Residence and Commons",
                latitude: 41.874282,
                longitude: -87.649813,
                features: [.bench, .shadedLocation, .accessible, .seating],
                imageName: nil,
                averageRating: 0,
                reviewCount: 0
            ),
            RestingSpot(
                id: IDs.uicPathBench1,
                name: "Bench",
                address: "",
                directions: "On the side of the sidewalk/path surrounded by green area",
                latitude: 41.873529,
                longitude: -87.649874,
                features: [.bench, .shadedLocation, .accessible, .seating],
                imageName: nil,
                averageRating: 0,
                reviewCount: 0
            ),
            
            RestingSpot(
                id: IDs.uicPathBench2,
                name: "Bench",
                address: "1007 W Harrison St, Chicago, IL 60607",
                directions: "Near the dead end on the road, on the side of the sidewalk/path near the UIS Behavioral Sciences Building",
                latitude: 41.873196,
                longitude: -87.651953,
                features: [.bench, .shadedLocation, .seating],
                imageName: nil,
                averageRating: 0,
                reviewCount: 0
            ),
            RestingSpot(
                id: IDs.uicPathBench3,
                name: "Seating",
                address: "Outdoor Seating Area on 2nd Floor (Stairs)",
                directions: "Take the stairs outside from behind the UIC Student Center East Building or come up to the second floor from the inside using the indoor elevators/excalators/stairs",
                latitude: 41.872651,
                longitude: -87.648080,
                features: [.bench, .seating],
                imageName: nil,
                averageRating: 0,
                reviewCount: 0
            ),

            // ============================================================
            // ADD YOUR SPOTS BELOW — copy this template and fill it in:
            //
            // RestingSpot(
            //     id: UUID(),  // must be unique — never reuse another spot's ID
            //     name: "Your Spot Name",
            //     address: "123 W Street, Chicago, IL 60607",
            //     directions: "Short tip on how to find it or what makes it good.",
            //     latitude: 41.8700,
            //     longitude: -87.6500,
            //     features: [.bench, .park, .shadedLocation],
            //     imageName: "your-asset-name",  // or nil if no photo yet
            //     averageRating: 0,
            //     reviewCount: 0
            // ),
            //
            // Available features:
            //   .bench, .park, .shadedLocation, .restroom,
            //   .waterFountain, .accessible, .seating
            // ============================================================
        ]
    }

    /// Sample reviews tied to the seed spots above.
    /// - Returns: Demo reviews for the info panel.
    static var reviews: [Review] {
        [
            Review(
                id: UUID(uuidString: "B1000001-0000-4000-8000-000000000001")!,
                spotID: IDs.maryBartelmePark,
                authorName: "Alex R.",
                rating: 5,
                comment: "Shaded benches and a calm vibe — perfect study break spot.",
                createdAt: Date().addingTimeInterval(-86_400)
            ),
            Review(
                id: UUID(uuidString: "B1000001-0000-4000-8000-000000000002")!,
                spotID: IDs.maryBartelmePark,
                authorName: "Jordan P.",
                rating: 4,
                comment: "Nice park in the West Loop. Easy to find near Sangamon.",
                createdAt: Date().addingTimeInterval(-172_800)
            ),
            Review(
                id: UUID(uuidString: "B1000001-0000-4000-8000-000000000003")!,
                spotID: IDs.uicEastCampusQuad,
                authorName: "Sam T.",
                rating: 4,
                comment: "Convenient between classes. Grab a bench under the trees.",
                createdAt: Date().addingTimeInterval(-259_200)
            )
        ]
    }
}
