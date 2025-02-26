import SwiftUI
import MapKit
import WidgetKit

struct MapView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var stopsStore = StopsDataStore.shared
    @State private var region = MKCoordinateRegion()
    @State private var selectedStop: [String: Any]?
    @State private var showLoadingIndicator = false
    @State private var centerMapOnUser = true
    
    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapViewRepresentable(
                    stops: stopsStore.stops,
                    userLocation: locationManager.location,
                    onAnnotationTapped: { annotation in
                        if let title = annotation.title ?? "",
                           let stop = stopsStore.stops.first(where: { ($0["name"] as? String) == title }) {
                            selectedStop = stop
                        }
                    },
                    centerMapOnUser: $centerMapOnUser
                )
                .edgesIgnoringSafeArea(.top)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: centerOnUser) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .padding()
                                .foregroundStyle(.white)
                                .background(.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
                
                if stopsStore.isLoading && showLoadingIndicator {
                    ProgressView()
                        .padding()
                        .background(Color(.systemBackground).opacity(1))
                        .cornerRadius(8)
                }
                
                if let error = stopsStore.error {
                    ErrorView(error: error, onRetry: refreshStops)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedStop != nil },
                set: { if !$0 { selectedStop = nil } }
            )) {
                if let stop = selectedStop {
                    BusStopView(stop: stop, isDeepLink: false)
                }
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { newLocation in
            guard let location = newLocation else { return }
            showLoadingIndicator = true
            if locationManager.shouldRefresh(for: location) {
                Task {
                    await stopsStore.loadStops(userLocation: location)
                    showLoadingIndicator = false
                }
            }
        }
    }
    
    private func centerOnUser() {
        guard locationManager.location != nil else {
            locationManager.requestLocation()
            return
        }
        
        centerMapOnUser = true
        showLoadingIndicator = true
        
        if let location = locationManager.location,
           locationManager.shouldRefresh(for: location) {
            Task {
                await stopsStore.loadStops(userLocation: location)
                showLoadingIndicator = false
            }
        } else {
            showLoadingIndicator = false
        }
    }
    
    private func refreshStops() {
        guard let location = locationManager.location else { return }
        Task {
            await stopsStore.loadStops(userLocation: location)
        }
    }
}

struct ErrorView: View {
    let error: Error
    let onRetry: () -> Void
    
    var body: some View {
        VStack {
            Text("Error loading stops")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
            Button("Retry", action: onRetry)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemBackground).opacity(1))
        .cornerRadius(8)
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    let stops: [[String: Any]]
    let userLocation: CLLocation?
    let onAnnotationTapped: (MKAnnotation) -> Void
    @Binding var centerMapOnUser: Bool
    private let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        
        // Enable all user interactions
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        
        // Set initial region if user location is available
        if let location = userLocation {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: defaultSpan
            )
            mapView.setRegion(region, animated: true)
            mapView.setCenter(location.coordinate, animated: true)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        updateAnnotations(on: mapView)
        updateOverlay(on: mapView)
        
        if centerMapOnUser, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: defaultSpan
            )
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async {
                centerMapOnUser = false
            }
        }
    }
    
    private func updateAnnotations(on mapView: MKMapView) {
        let existingAnnotations = mapView.annotations.compactMap { $0 as? MKPointAnnotation }
        let existingStopTitles = Set(existingAnnotations.compactMap { $0.title })
        let newStopTitles = Set(stops.compactMap { $0["name"] as? String })
        
        if existingStopTitles != newStopTitles {
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            
            for stop in stops {
                if let centre = stop["centre"] as? [String: Any],
                   let geographic = centre["geographic"] as? [String: Any],
                   let lat = Double(geographic["latitude"] as? String ?? ""),
                   let lon = Double(geographic["longitude"] as? String ?? "") {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    annotation.title = stop["name"] as? String
                    annotation.subtitle = formatSubtitle(for: stop)
                    mapView.addAnnotation(annotation)
                }
            }
        }
    }
    
    private func updateOverlay(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)
        if let userLocation = userLocation {
            let circle = MKCircle(center: userLocation.coordinate, radius: getStopsDistanceRadius())
            mapView.addOverlay(circle)
        }
    }
    
    private func formatSubtitle(for stop: [String: Any]) -> String {
        var subtitle = "#\(stop["number"] as? Int ?? 0)"
        var variantsString = ""
        
        if let variants = stop["variants"] as? [[String: Any]] {
            let uniqueRoutes = Set(variants.compactMap { variant -> String? in
                guard let variantDict = variant["variant"] as? [String: Any],
                      let key = variantDict["key"] as? String else { return nil }
                return key.split(separator: "-")[0].description
            })
            variantsString = uniqueRoutes.joined(separator: ", ")
        }
        
        subtitle += ": " + variantsString
        subtitle += " - " + (stop["direction"] as? String ?? "Unknown Direction")
        return subtitle
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        
        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "StopPin"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                let button = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = button
            } else {
                annotationView?.annotation = annotation
            }
            
            if let subtitle = annotation.subtitle,
               let direction = subtitle?.components(separatedBy: " - ").last {
                let markerImage: UIImage?
                switch direction.lowercased() {
                case "southbound": markerImage = UIImage(named: "GreenBall")
                case "northbound": markerImage = UIImage(named: "OrangeBall")
                case "eastbound": markerImage = UIImage(named: "PinkBall")
                case "westbound": markerImage = UIImage(named: "BlueBall")
                default: markerImage = UIImage(named: "DefaultBall")
                }
                
                if let image = markerImage {
                    let size = CGSize(width: 32, height: 32)
                    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                    image.draw(in: CGRect(origin: .zero, size: size))
                    
                    if let context = UIGraphicsGetCurrentContext() {
                        context.setBlendMode(.plusLighter)
                        let brightSpotPath = UIBezierPath(ovalIn: CGRect(x: size.width * 0.35,
                                                                        y: size.height * 0.1,
                                                                        width: size.width * 0.1,
                                                                        height: size.height * 0.1))
                        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
                        brightSpotPath.fill()
                    }
                    
                    annotationView?.image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    annotationView?.frame.size = size
                }
            }
            
            annotationView?.layer.shadowColor = UIColor.black.cgColor
            annotationView?.layer.shadowOffset = CGSize(width: 0, height: 1)
            annotationView?.layer.shadowOpacity = 0.3
            annotationView?.layer.shadowRadius = 1
            annotationView?.displayPriority = .required
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circleOverlay = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circleOverlay)
                renderer.fillColor = .clear
                renderer.strokeColor = .accent
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let annotation = view.annotation {
                parent.onAnnotationTapped(annotation)
            }
        }
    }
}
