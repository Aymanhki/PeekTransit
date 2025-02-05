import SwiftUI
import WidgetKit


struct DynamicWidgetView: View {
    let widgetData: [String: Any]
    let scheduleData: [String]?
    let size: WidgetFamily
    let updatedAt: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            
            
            
            if (widgetData["showLastUpdatedStatus"] as? Bool ?? true) {
                
                if (size != .accessoryRectangular) {
                    
                    if (size != .systemMedium || (scheduleData)?.count ?? 0 <= 3) {
                        Spacer(minLength: 2)
                    }
                }
                
                
                
                LastUpdatedView(updatedAt: updatedAt, size: size == .systemSmall ? "small" : size == .systemMedium ? "medium" : size == .systemLarge ? "large" : "lockscreen")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
    }
    
    @ViewBuilder
    private var content: some View {
        selectedStopsView
    }
    
    
    
    @ViewBuilder
    private var selectedStopsView: some View {
        if let stops = widgetData["stops"] as? [[String: Any]] {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(stops.prefix(maxStops)).indices, id: \.self) { stopIndex in
                    let stop = stops[stopIndex]
                    StopView(stop: stop, scheduleData: scheduleData, size: size)
                    
                    if (stopIndex < stops.prefix(maxStops).count - 1 && size != .accessoryRectangular) {
                        Divider()
                    }
                }
            }
        }
    }
    
    private var maxStops: Int {
        return getMaxSopsAllowed(widgetSizeSystemFormat: size, widgetSizeStringFormat: nil)
    }
    
    private var maxSchedules: Int {
        return getMaxVariantsAllowed(widgetSizeSystemFormat: size, widgetSizeStringFormat: nil)
    }
}

struct BusScheduleRow: View {
    let schedule: String
    let size: WidgetFamily
    
    var body: some View {
        let components = schedule.components(separatedBy: " ---- ")
        if components.count >= 4 {
            HStack {
                Text(components[0])
                    .font(.system(size: fontSize, design: .monospaced))
                    .bold()
                
                if !components[1].isEmpty {
                    
                    if (size != .systemSmall && size != .accessoryRectangular) {
                        Text(components[1])
                            .font(.system(size: fontSize - 2, design: .monospaced))
                            .padding(.leading, 2)
                            .bold()
                    
                    } else {
                        if (components[2] == "Late" || components[2] == "Early" || components[2] == "Cancelled" || components[1].count > 3) {
                            
                            Text("\(components[1].prefix(1)).")
                                .font(.system(size: fontSize - 2, design: .monospaced))
                                .padding(.leading, 2)
                                .bold()
                        } else {
                            Text(components[1])
                                .font(.system(size: fontSize - 2, design: .monospaced))
                                .padding(.leading, 2)
                                .bold()
                        }
                        
                    }
                }
                
                Spacer()
                
                if (components[2] == "Late" || components[2] == "Early" ||  components[2] == "Cancelled") {
                    if ( (size == .systemSmall || size == .accessoryRectangular) &&  components[2] != "Cancelled" ) {
                        Text("\(components[2].prefix(1)).")
                            .foregroundColor((components[2] == "Late" || components[2] == "Cancelled")  ? .red : .blue)
                            .font(.system(size: fontSize - 2, design: .monospaced))
                            .bold()
                        
                        
                    } else {
                        Text(components[2])
                            .foregroundColor((components[2] == "Late" || components[2] == "Cancelled") ? .red : .blue)
                            .font(.system(size: fontSize - 2, design: .monospaced))
                            .frame(alignment: .leading)
                            .bold()
                    }
                }
                
                if (components[2] != "Cancelled") {
                    Text(components[3])
                        .font(.system(size: fontSize, design: .monospaced))
                        .bold()
                        .frame(alignment: .leading)
                }
            }
            
        }
    }
    
    private var fontSize: CGFloat {
        switch size {
        case .systemLarge: return 16
        case .systemMedium: return 15
        case .systemSmall: return 14
        case .accessoryRectangular: return 12
        default: return 12
        }
    }
}

struct StopView: View {
    let stop: [String: Any]
    let scheduleData: [String]?
    let size: WidgetFamily
    let stopNamePrefixSize = 40
    
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let stopName = stop["name"] as? String ?? "Unknown Stop"
            let stopNamePrefix = "\(stopName.prefix(stopNamePrefixSize))..."
            

            if (size != .accessoryRectangular) {
                if (size == .systemSmall) {
                    Text("• \(stopName.count > stopNamePrefixSize ? stopNamePrefix : stopName)")
                        .font(.system(size:  8))
                } else if (size == .systemLarge) {
                    Text("• \(stopName)")
                        .font(.system(.caption2))
                } else {
                    Text("• \(stopName.count > stopNamePrefixSize ? stopNamePrefix : stopName)")
                        .font(.system(.caption2))
                        .padding(.bottom, 1)
                }
                
               if (size == .systemLarge || size == .systemSmall || (scheduleData)?.count ?? 0 < 3) {
                    Spacer()
                }
            }
            
            if let variants = stop["selectedVariants"] as? [[String: Any]] {
                let maxSchedules =  getMaxVariantsAllowed(widgetSizeSystemFormat: size, widgetSizeStringFormat: nil)

                ForEach(variants.prefix(maxSchedules).indices, id: \.self) { variantIndex in
                    if let key = variants[variantIndex]["key"] as? String,
                       let schedules = scheduleData,
                       let variantName = variants[variantIndex]["name"] as? String,
                       let matchingSchedule = schedules.first(where: { scheduleString in
                           let components = scheduleString.components(separatedBy: " ---- ")
                           return components.count >= 2 &&
                                  components[0] == key &&
                                  components[1] == variantName
                       }) {
                        
                        if (size == .systemSmall || size == .accessoryRectangular) {
                            BusScheduleRow(schedule: matchingSchedule, size: size)
                                .padding(.horizontal, 8)
                            
                            
                        } else if (size != .systemMedium && size != .accessoryRectangular) {
                            BusScheduleRow(schedule: matchingSchedule, size: size)
                                .padding(.horizontal, 30)
                        } else if (size == .systemMedium) {
                            BusScheduleRow(schedule: matchingSchedule, size: size)
                                .padding(.horizontal, 30)
                                .padding(.bottom, variantIndex < variants.prefix(maxSchedules).count  - 1 ? 3 : 0)
                        } else if (size == .accessoryRectangular) {
                            BusScheduleRow(schedule: matchingSchedule, size: size)
                        }
                        
                        if (size == .systemLarge || size == .systemSmall || ( ((scheduleData)?.count ?? 0 < 3) && size != .accessoryRectangular )) {
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}


struct LastUpdatedView: View {
    let updatedAt: Date
    let size: String
    
    var body: some View {
        Text("Last updated at \(formattedTime)")
            .font(.system(size:  size == "small" ? 10 : size == "lockscreen" ? 10 : 12))
            
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: updatedAt)
    }
}
