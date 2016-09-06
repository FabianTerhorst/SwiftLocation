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
	case Entered
	case Exited
}

/**
*  This option set define the type of events you can monitor via BeaconManager class's monitor() func
*/
public struct Event : OptionSetType {
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
	case Pending
	case Paused
	case Cancelled(error: LocationError?)
	case Running
	case WaitingUserAuth
	case Undetermined
	
	/// Request is running
	public var isRunning: Bool {
		switch self {
		case .Running:
			return true
		default:
			return false
		}
	}
	
	/// Request is not running but can be started anytime
	public var canStart: Bool {
		switch self {
		case .Paused, .Pending:
			return true
		default:
			return false
		}
	}
	
	/// Request is on queue but it's in pause state
	public var isPending: Bool {
		switch self {
		case .Pending, .WaitingUserAuth:
			return true
		default:
			return false
		}
	}
	
	/// Request is on queue but it's in pause state
	public var isCancelled: Bool {
		switch self {
		case .Cancelled(_):
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
	func cancel(error: LocationError?)
	
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
public typealias LocationHandlerAuthDidChange = (CLAuthorizationStatus? -> Void)

public typealias RegionStateDidChange = (RegionState -> Void)
public typealias RegionMonitorError = (LocationError -> Void)

// MARK: - CLAuthorizationStatus description implementation
extension CLAuthorizationStatus: CustomStringConvertible {
	public var description: String {
		switch self {
		case .Denied:
			return "User Denied"
		case .AuthorizedAlways:
			return "Always Authorized"
		case .NotDetermined:
			return "Not Determined"
		case .Restricted:
			return "Restricted"
		case .AuthorizedWhenInUse:
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
public enum LocationError: ErrorType, CustomStringConvertible {
	case MissingAuthorizationInPlist
	case RequestTimeout
	case AuthorizationDidChange(newStatus: CLAuthorizationStatus)
	case LocationManager(error: NSError?)
	case LocationNotAvailable
	case NoDataReturned
	case NotSupported
	case InvalidBeaconData
	
	public var description: String {
		switch self {
		case .MissingAuthorizationInPlist:
			return "Missing Authorization in .plist file"
		case .RequestTimeout:
			return "Timeout for request"
		case .AuthorizationDidChange(let status):
			return "Failed due to user auth status: '\(status)'"
		case .LocationManager(let err):
			if let error = err {
				return "Location manager error: \(error.localizedDescription)"
			} else {
				return "Generic location manager error"
			}
		case .LocationNotAvailable:
			return "Location not avaiable"
		case .NoDataReturned:
			return "No Data Returned"
		case .NotSupported:
			return "Feature Not Supported"
		case .InvalidBeaconData:
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
	case Disabled
	case Undetermined
	case Denied
	case Restricted
	case Authorized(always: Bool)
}

public func == (lhs: LocationServiceState, rhs: LocationServiceState) -> Bool {
	switch (lhs,rhs) {
	case (.Authorized(let a1), .Authorized(let a2)):
		return a1 == a2
	case (.Disabled,.Disabled), (.Undetermined,.Undetermined), (.Denied,.Denied), (.Restricted,.Restricted):
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
	case None
	case Always
	case OnlyInUse
}

// MARK: - CLLocationManager

extension CLLocationManager {
	
		/// This var return the current status of the location manager authorization session
	public static var locationAuthStatus: LocationServiceState {
		get {
			if CLLocationManager.locationServicesEnabled() == false {
				return .Disabled
			} else {
				let status = CLLocationManager.authorizationStatus()
				switch status {
				case .NotDetermined:
					return .Undetermined
				case .Denied:
					return .Denied
				case .Restricted:
					return .Restricted
				case .AuthorizedAlways:
					return .Authorized(always: true)
				case .AuthorizedWhenInUse:
					return .Authorized(always: false)
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
		let hasAlwaysAuth = (NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationAlwaysUsageDescription") != nil)
		let hasInUseAuth = (NSBundle.mainBundle().objectForInfoDictionaryKey("NSLocationWhenInUseUsageDescription") != nil)
		
		if hasAlwaysAuth == true { return .Always }
		if hasInUseAuth == true { return .OnlyInUse }
		return .None
	}
}