import Foundation

extension Int {
    var degreesToRadians: Double { return Double(self) * .pi / 180 }
    var radiansToDegrees: Double { return Double(self) * 180 / .pi }
}
extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

public func Distance(latitudeA_degre: String, longitudeA_degre: String, latitudeB_degre: String, longitudeB_degre: String) -> Double {

        //Convertir les données en float 
        //let latitudeA_deg_float = (latitudeA_degre as NSString).floatValue
        let latitudeA_deg_float = Double(latitudeA_degre)
        let longitudeA_deg_float = Double(longitudeA_degre)
        let latitudeB_deg_float = Double(latitudeB_degre)
        let longitudeB_deg_float = Double(longitudeB_degre)

        //Convertir les données de degrés en radian 
        let latitudeA = Double(latitudeA_deg_float!).degreesToRadians
        let longitudeA = Double(longitudeA_deg_float!).degreesToRadians
        let latitudeB = Double(latitudeB_deg_float!).degreesToRadians
        let longitudeB = Double(longitudeB_deg_float!).degreesToRadians

        var RayonTerre : Double
        RayonTerre = 63780000 //Rayon de la terre en mètre
        //var resultDistance: Float

        let distanceResult = RayonTerre * ((3.14159265/2) - asin(sin(latitudeB) * sin(latitudeA) + cos(longitudeB - longitudeA) * cos(latitudeB) * cos(latitudeA)))


        return distanceResult/10000
}

var latitudeMobile = "42.464436000000006"

var longitudeMobile = "2.863136"

var latitudeCible = "42.688659111"

var longitudeCible = "3.003078"

var radiusMobile = 20 //Km

var resultDistance : Double

resultDistance = Distance(latitudeA_degre: latitudeMobile, longitudeA_degre: longitudeMobile, latitudeB_degre: latitudeCible, longitudeB_degre: longitudeCible) //Appel de la fonction distance

	// if resultDistance < radiusFloat! / 1000 {  //Comparaison de la distance entre les deux points et le radius


	// }

print(resultDistance)