//
//  SwiftLocation.swift
//  SwiftLocations
//
// Copyright (c) 2016 Daniele Margutti
// Web:			http://www.danielemargutti.com
// Mail:		me@danielemargutti.com
// Twitter:		@danielemargutti
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import CoreLocation

/**
State of the beacon region monitoring

- Entered: entered into the region
- Exited:  exited from the region
*/
public enum RegionState {
	case entered
	case exited
}

/**
*  This option set define the type of events you can monitor via BeaconManager class's monitor() func
*/
public struct Event : OptionSet {
	public let rawValue: UInt8
	public init(rawValue: UInt8) { self.rawValue = rawValue }
	
	/// Monitor a region cross boundary event (enter and exit from the region)
	public static let RegionBoundary = Event(rawValue: 1 << 0)
	/// Monitor beacon ranging
	public static let Ranging = Event(rawValue: 1 << 1)
	/// Monitor both region cross boundary and beacon ranging events
	public static let All : Event = [RegionBoundary, Ranging]
}

/**
This define the state of a request. Usually you don't need to acces to this info

- Pending:         A request is pending when it's never started
- Paused:          A request is paused when it's on queue but it will not receive any events
- Cancelled:       A cancelled request cannot be queued again
- Running:         A request is running when it's on queue and will receive events
- WaitingUserAuth: In this state the request is paused and the system is waiting for user authorization
- Undetermined:    Undetermined state is usually used when the object cannot support request protocol
*/
public enum RequestState {
	case pending
	case paused
	case cancelled(error: LocationError?)
	case running
	case waitingUserAuth
	case undetermined
	
	/// Request is running
	public var isRunning: Bool {
		switch self {
		case .running:
			return true
		default:
			return false
		}
	}
	
	/// Request is not running but can be started anytime
	public var canStart: Bool {
		switch self {
		case .paused, .pending:
			return true
		default:
			return false
		}
	}
	
	/// Request is on queue but it's in pause state
	public var isPending: Bool {
		switch self {
		case .pending, .waitingUserAuth:
			return true
		default:
			return false
		}
	}
	
	/// Request is on queue but it's in pause state
	public var isCancelled: Bool {
		switch self {
		case .cancelled(_):
			return true
		default:
			return false
		}
	}
}

/**
*  Each request in SwiftLocation support this protocol
*/
public protocol Request {
	/**
	Cancel a running active request. Remove it from queue and mark it as cancelled.
	
	- parameter error: optional error to cancel the request
	*/
	func cancel(_ error: LocationError?)
	
	/**
	Pause a running request
	*/
	func pause()
	
	/**
	Start a request by adding it to the relative queue
	*/
	func start()
	
	/// Unique identifier of the request
	var UUID: String { get }
	
	/// State of the request
	var rState: RequestState { get }
	
	//  You can observe for authorization changes in CLLocationManager
	var onAuthorizationDidChange: LocationHandlerAuthDidChange? { get set }
}

/// Handlers
public typealias LocationHandlerAuthDidChange = ((CLAuthorizationStatus?) -> Void)

public typealias RegionStateDidChange = ((RegionState) -> Void)
public typealias RegionMonitorError = ((LocationError) -> Void)

// MARK: - CLAuthorizationStatus description implementation
extension CLAuthorizationStatus: CustomStringConvertible {
	public var description: String {
		switch self {
		case .denied:
			return "User Denied"
		case .authorizedAlways:
			return "Always Authorized"
		case .notDetermined:
			return "Not Determined"
		case .restricted:
			return "Restricted"
		case .authorizedWhenInUse:
			return "Authorized In Use"
		}
	}
}

// MARK: - Location Errors

/**
Define all possible error related to SwiftLocation library

- MissingAuthorizationInPlist: Missing authorization in plist file (NSLocationAlwaysUsageDescription,NSLocationWhenInUseUsageDescription)
- RequestTimeout:              Request has timed out
- AuthorizationDidChange:      Authorization status of the location manager did change due to user's interaction
- LocationManager:             Location manager's error
- LocationNotAvailable:        Requested location is not available
- NoDataReturned:              No data returned from this request
- NotSupported:                Feature is not supported by the current hardware
*/
public enum LocationError: Error, CustomStringConvertible {
	case missingAuthorizationInPlist
	case requestTimeout
	case authorizationDidChange(newStatus: CLAuthorizationStatus)
	case locationManager(error: NSError?)
	case locationNotAvailable
	case noDataReturned
	case notSupported
	case invalidBeaconData
	
	public var description: String {
		switch self {
		case .missingAuthorizationInPlist:
			return "Missing Authorization in .plist file"
		case .requestTimeout:
			return "Timeout for request"
		case .authorizationDidChange(let status):
			return "Failed due to user auth status: '\(status)'"
		case .locationManager(let err):
			if let error = err {
				return "Location manager error: \(error.localizedDescription)"
			} else {
				return "Generic location manager error"
			}
		case .locationNotAvailable:
			return "Location not avaiable"
		case .noDataReturned:
			return "No Data Returned"
		case .notSupported:
			return "Feature Not Supported"
		case .invalidBeaconData:
			return "Cannot create monitor for beacon. Invalid data"
		}
	}
}

/**
Location service state

- Undetermined: No authorization status could be determined.
- Denied:       The user explicitly denied access to location data for this app.
- Restricted:   This app is not authorized to use location services. The user cannot change this app’s status, possibly due to active restrictions such as parental controls being in place.
- Authorized:   This app is authorized to use location services.
*/
public enum LocationServiceState: Equatable {
	case disabled
	case undetermined
	case denied
	case restricted
	case authorized(always: Bool)
}

public func == (lhs: LocationServiceState, rhs: LocationServiceState) -> Bool {
	switch (lhs,rhs) {
	case (.authorized(let a1), .authorized(let a2)):
		return a1 == a2
	case (.disabled,.disabled), (.undetermined,.undetermined), (.denied,.denied), (.restricted,.restricted):
		return true
	default:
		return false
	}
}

/**
Location authorization status

- None:      no authorization was provided
- Always:    app can receive location updates both in background and foreground
- OnlyInUse: app can receive location updates only in foreground
*/
public enum LocationAuthType {
	case none
	case always
	case onlyInUse
}

// MARK: - CLLocationManager

extension CLLocationManager {
	
		/// This var return the current status of the location manager authorization session
	public static var locationAuthStatus: LocationServiceState {
		get {
			if CLLocationManager.locationServicesEnabled() == false {
				return .disabled
			} else {
				let status = CLLocationManager.authorizationStatus()
				switch status {
				case .notDetermined:
					return .undetermined
				case .denied:
					return .denied
				case .restricted:
					return .restricted
				case .authorizedAlways:
					return .authorized(always: true)
				case .authorizedWhenInUse:
					return .authorized(always: false)
				}
			}
		}
	}
	
		/// This var return the current status of the application's configuration
		/// Since iOS8 you must specify a key which define the usage type of the location manager; you can use
		/// NSLocationAlwaysUsageDescription if your app can uses location manager both in background and foreground or
		/// NSLocationWhenInUseUsageDescription if your app is limited to foreground location update only.
		/// Value of these keys if the message you want to show into system location request message the first time you
		/// will access to the location manager.
	internal static var bundleLocationAuthType: LocationAuthType {
		let hasAlwaysAuth = (Bundle.main.object(forInfoDictionaryKey: "NSLocationAlwaysUsageDescription") != nil)
		let hasInUseAuth = (Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil)
		
		if hasAlwaysAuth == true { return .always }
		if hasInUseAuth == true { return .onlyInUse }
		return .none
	}
}
