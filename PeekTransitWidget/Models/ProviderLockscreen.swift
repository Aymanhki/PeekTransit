import WidgetKit
import SwiftUI
import Intents
import Combine
import Foundation



struct ProviderLockscreen: IntentTimelineProvider {
    typealias Entry = SimpleEntryLockscreen
    
    func placeholder(in context: Context) -> SimpleEntryLockscreen {
        SimpleEntryLockscreen(date: Date(), configuration: ConfigurationLockscreenIntent())
    }
    
    func getSnapshot(for configuration: ConfigurationLockscreenIntent, in context: Context, completion: @escaping (SimpleEntryLockscreen) -> Void) {
        Task {
            if let widgetId = configuration.widgetConfig?.identifier,
               let widget = WidgetHelper.getWidgetFromDefaults(withId: widgetId) {
                
                var finalWidgetData = widget.widgetData
                
                if widget.widgetData["isClosestStop"] as? Bool == true {
                    if let location = await LocationManager.shared.getCurrentLocation() {
                        let nearbyStops = try? await TransitAPI.shared.getNearbyStops(userLocation: location, forShort: getGlobalAPIForShortUsage())
                        if let stops = nearbyStops, !stops.isEmpty {
                            let maxStops = WidgetHelper.getMaxSopsAllowedForWidget(
                                widgetSizeSystemFormat: .accessoryRectangular,
                                widgetSizeStringFormat: nil
                            )
                            finalWidgetData["stops"] = await WidgetHelper.getFilteredStopsForWidget(stops, maxStops: maxStops, widgetData: widget.widgetData)
                            let (schedule, updatedWidgetData) = await WidgetHelper.getScheduleForWidget(finalWidgetData, isClosestStop: true)
                            finalWidgetData = updatedWidgetData
                            
                            completion(SimpleEntryLockscreen(
                                date: Date(),
                                configuration: configuration,
                                widgetData: finalWidgetData,
                                scheduleData: schedule
                            ))
                        }
                    }
                } else {
                    let (schedule, updatedWidgetData) = await WidgetHelper.getScheduleForWidget(finalWidgetData)
                    completion(SimpleEntryLockscreen(
                        date: Date(),
                        configuration: configuration,
                        widgetData: updatedWidgetData,
                        scheduleData: schedule
                    ))
                }
            } else {
                completion(SimpleEntryLockscreen(date: Date(), configuration: configuration))
            }
        }
    }
    
    func getTimeline(for configuration: ConfigurationLockscreenIntent, in context: Context, completion: @escaping (Timeline<SimpleEntryLockscreen>) -> Void) {
        Task {
            let widgetId = configuration.widgetConfig?.identifier
            let widget = widgetId.flatMap { WidgetHelper.getWidgetFromDefaults(withId: $0) }
            var widgetData = widget?.widgetData
            
            if widget?.widgetData["isClosestStop"] as? Bool == true {
                if let location = await LocationManager.shared.getCurrentLocation() {
                    let nearbyStops = try? await TransitAPI.shared.getNearbyStops(userLocation: location, forShort: getGlobalAPIForShortUsage())
                    if let stops = nearbyStops, !stops.isEmpty {
                        let maxStops = WidgetHelper.getMaxSopsAllowedForWidget(
                            widgetSizeSystemFormat: .accessoryRectangular,
                            widgetSizeStringFormat: nil
                        )
                        widgetData?["stops"] = await WidgetHelper.getFilteredStopsForWidget(stops, maxStops: maxStops, widgetData: widget?.widgetData)
                        let (_, updatedWidgetData) = await WidgetHelper.getScheduleForWidget(widgetData ?? [:], isClosestStop: true)
                        widgetData = updatedWidgetData
                    }
                }
            }
            
            let timeline = await WidgetHelper.createTimeline(
                currentDate: Date(),
                configuration: configuration,
                widgetData: widgetData
            ) { date, config, data, schedule in
                SimpleEntryLockscreen(
                    date: date,
                    configuration: config as! ConfigurationLockscreenIntent,
                    widgetData: data,
                    scheduleData: schedule
                )
            }
            
            let nextUpdate = Calendar.current.date(byAdding: .second, value: getRefreshWidgetTimelineAfterHowManySeconds(), to: Date())!
               let timelineWithShorterUpdate = Timeline(
                   entries: timeline.entries,
                   policy: .after(nextUpdate)
               )
               
               completion(timelineWithShorterUpdate)
        }
    }
}
