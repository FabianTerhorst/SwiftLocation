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

public let Beacons :BeaconsManager = BeaconsManager.shared

open class BeaconsManager : NSObject, CLLocationManagerDelegate {
	open static let shared = BeaconsManager()
	
	//MARK Private Variables
	internal var manager: CLLocationManager

	internal var monitoredGeoRegions: [GeoRegionRequest] = []

	/// This identify the largest boundary distance allowed from a region’s center point.
	/// Attempting to monitor a region with a distance larger than this value causes the location manager
	/// to send a regionMonitoringFailure error when you monitor a region.
	open var maximumRegionMonitoringDistance: CLLocationDistance {
		get {
			return self.manager.maximumRegionMonitoringDistance
		}
	}
	
	fileprivate override init() {
		self.manager = CLLocationManager()
		super.init()
		self.cleanAllMonitoredRegions()
		self.manager.delegate = self
	}
	
	/**
	Remove any monitored region
	(it will be executed automatically on login)
	*/
	open func cleanAllMonitoredRegions() {
		self.manager.monitoredRegions.forEach { self.manager.stopMonitoring(for: $0) }
	}

	//MARK: Public Methods

	/**
	You can use the region-monitoring service to be notified when the user crosses a region-based boundary.
	
	- parameter coordinates:      the center point of the region
	- parameter radius:           the radius of the region in meters
	- parameter onStateDidChange: event fired when region in/out events are catched
	- parameter onError:          event fired in case of error. request is aborted automatically
	
	- throws: throws an exception if monitor is not supported or invalid region was specified
	
	- returns: request
	*/
	open func monitor(geographicRegion coordinates: CLLocationCoordinate2D, radius: CLLocationDistance, onStateDidChange: @escaping RegionStateDidChange, onError: @escaping RegionMonitorError) throws -> GeoRegionRequest {
		if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) == false {
			throw LocationError.notSupported
		}
		let request = GeoRegionRequest(coordinates: coordinates, radius: radius)
		request.onStateDidChange = onStateDidChange
		request.onError = onError
		self.add(request: request)
		return request
	}
	
	internal func add(request: Request) -> Bool {
		if request.rState.canStart == false {
			return false
		}
		if self.monitoredGeoRegions.filter({ $0.UUID == request.UUID }).first != nil {
			return false
		}
		
		do {
			if let request = request as? GeoRegionRequest {
				self.monitoredGeoRegions.append(request)
				if try self.requestLocationServiceAuthorizationIfNeeded() == false {
					self.manager.startMonitoring(for: request.region)
					return true
				}
				return false
			}
			return false
		} catch let err {
			self.remove(request: request, error: (err as? LocationError) )
			return false
		}
	}
	
	internal func remove(request: Request?, error: LocationError? = nil) -> Bool {
		guard let request = request else { return false }
		if let request = request as? GeoRegionRequest {
			guard let idx = self.monitoredGeoRegions.index(where: { $0.UUID == request.UUID }) else {
				return false
			}
			request.rState = .cancelled(error: error)
			self.manager.stopMonitoring(for: request.region)
			self.monitoredGeoRegions.remove(at: idx)
			return true
		}
		return false
	}
	
	fileprivate func requestLocationServiceAuthorizationIfNeeded() throws -> Bool {
		if CLLocationManager.locationAuthStatus == .authorized(always: true) || CLLocationManager.locationAuthStatus == .authorized(always: false) {
			return false
		}
		
		switch CLLocationManager.bundleLocationAuthType {
		case .none:
			throw LocationError.missingAuthorizationInPlist
		case .always:
			self.manager.requestAlwaysAuthorization()
		case .onlyInUse:
			self.manager.requestWhenInUseAuthorization()
		}
		
		return true
	}
	
	fileprivate func dispatchAuthorizationDidChange(_ newStatus: CLAuthorizationStatus) {
		func _dispatch(_ request: Request) {
			request.onAuthorizationDidChange?(newStatus)
		}
		
		self.monitoredGeoRegions.forEach({ _dispatch($0) })
	}
	
	//MARK: Location Manager Beacon/Geographic Regions
	
	@objc open func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
		self.monitoredGeoRegions.filter { $0.region.identifier == region.identifier }.first?.onStateDidChange?(.entered)
	}
	
	@objc open func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
		self.monitoredGeoRegions.filter {  $0.region.identifier == region.identifier }.first?.onStateDidChange?(.exited)
	}
	
	@objc open func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
		let error = LocationError.locationManager(error: error)
		self.remove(request: self.monitoredGeo(forRegion: region), error: error)
	}
	
	//MARK: Helper Methods
	
	fileprivate func monitoredGeo(forRegion region: CLRegion?) -> Request? {
		guard let region = region else { return nil }
		let request = self.monitoredGeoRegions.filter { $0.region.identifier == region.identifier }.first
		return request
	}
}
