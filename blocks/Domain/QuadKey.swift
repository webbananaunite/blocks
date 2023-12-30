//
//  QuadKey.swift
//  blocks
//
//  Created by よういち on 2023/08/02.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit
import MapKit

//------------------------------------------------------------------------------
// <copyright company="Microsoft">
//     Copyright (c) 2006-2009 Microsoft Corporation.  All rights reserved.
// </copyright>
//------------------------------------------------------------------------------
open class QuadKey: NSObject, ObservableObject, CLLocationManagerDelegate {
    private static let EarthRadius: Double = 6378137
    private static let MinLatitude: Double = -85.05112878
    private static let MaxLatitude: Double = 85.05112878
    private static let MinLongitude: Double = -180
    private static let MaxLongitude: Double = 180
    
    public static let levelOfDetail = 20  //←これが文字数となる
    
    /// <summary>
    /// Clips a number to the specified minimum and maximum values.
    /// </summary>
    /// <param name="n">The number to clip.</param>
    /// <param name="minValue">Minimum allowable value.</param>
    /// <param name="maxValue">Maximum allowable value.</param>
    /// <returns>The clipped value.</returns>
    private static func Clip(n: Double, minValue: Double, maxValue: Double) -> Double {
        return min(max(n, minValue), maxValue)
    }
    
    /// <summary>
    /// Determines the map width and height (in pixels) at a specified level
    /// of detail.
    /// </summary>
    /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
    /// to 23 (highest detail).</param>
    /// <returns>The map width and height in pixels.</returns>
    public static func MapSize(levelOfDetail: Int) -> UInt {
        return 256 << levelOfDetail as UInt
    }
    
    /// <summary>
    /// Determines the ground resolution (in meters per pixel) at a specified
    /// latitude and level of detail.
    /// </summary>
    /// <param name="latitude">Latitude (in degrees) at which to measure the
    /// ground resolution.</param>
    /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
    /// to 23 (highest detail).</param>
    /// <returns>The ground resolution, in meters per pixel.</returns>
    public static func GroundResolution(latitude: inout Double, levelOfDetail: Int) -> Double {
        latitude = Clip(n: latitude, minValue: MinLatitude, maxValue: MaxLatitude)
        return cos(latitude * Double.pi / 180) * 2 * Double.pi * EarthRadius / Double(MapSize(levelOfDetail: levelOfDetail))
    }
    
    /// <summary>
    /// Determines the map scale at a specified latitude, level of detail,
    /// and screen resolution.
    /// </summary>
    /// <param name="latitude">Latitude (in degrees) at which to measure the
    /// map scale.</param>
    /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
    /// to 23 (highest detail).</param>
    /// <param name="screenDpi">Resolution of the screen, in dots per inch.</param>
    /// <returns>The map scale, expressed as the denominator N of the ratio 1 : N.</returns>
    public static func MapScale(latitude: inout Double, levelOfDetail: Int, screenDpi: Int) -> Double {
        return GroundResolution(latitude: &latitude, levelOfDetail: levelOfDetail) * Double(screenDpi) / 0.0254
    }
    
    /// <summary>
    /// Converts a point from latitude/longitude WGS-84 coordinates (in degrees)
    /// into pixel XY coordinates at a specified level of detail.
    /// </summary>
    /// <param name="latitude">Latitude of the point, in degrees.</param>
    /// <param name="longitude">Longitude of the point, in degrees.</param>
    /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
    /// to 23 (highest detail).</param>
    /// <param name="pixelX">Output parameter receiving the X coordinate in pixels.</param>
    /// <param name="pixelY">Output parameter receiving the Y coordinate in pixels.</param>
    public static func LatLongToPixelXY(latitude: Double, longitude: Double, levelOfDetail: Int = QuadKey.levelOfDetail, pixelX: inout Int, pixelY: inout Int) -> Void {
        let latitude = Clip(n: latitude, minValue: MinLatitude, maxValue: MaxLatitude)
        let longitude = Clip(n: longitude, minValue: MinLongitude, maxValue: MaxLongitude)
        
        let x: Double = (longitude + 180) / 360
        let sinLatitude: Double = sin(latitude * Double.pi / 180)
        let y: Double = 0.5 - log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * Double.pi)
        
        let mapSize: UInt = MapSize(levelOfDetail: levelOfDetail)
        pixelX = Int(Clip(n: x * Double(mapSize) + 0.5, minValue: 0, maxValue: Double(mapSize) - 1))
        pixelY = Int(Clip(n: y * Double(mapSize) + 0.5, minValue: 0, maxValue: Double(mapSize) - 1))
    }
    
    /// <summary>
    /// Converts a pixel from pixel XY coordinates at a specified level of detail
    /// into latitude/longitude WGS-84 coordinates (in degrees).
    /// </summary>
    /// <param name="pixelX">X coordinate of the point, in pixels.</param>
    /// <param name="pixelY">Y coordinates of the point, in pixels.</param>
    /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
    /// to 23 (highest detail).</param>
    /// <param name="latitude">Output parameter receiving the latitude in degrees.</param>
    /// <param name="longitude">Output parameter receiving the longitude in degrees.</param>
    public static func PixelXYToLatLong(pixelX: Int, pixelY: Int, levelOfDetail: Int, latitude: inout Double, longitude: inout Double) -> Void {
        let mapSize: Double = Double(MapSize(levelOfDetail: levelOfDetail))
        let x: Double = (Clip(n: Double(pixelX), minValue: 0, maxValue: mapSize - 1) / mapSize) - 0.5
        let y: Double = 0.5 - (Clip(n: Double(pixelY), minValue: 0, maxValue: mapSize - 1) / mapSize)
        
        latitude = 90 - 360 * atan(exp(-y * 2 * Double.pi)) / Double.pi
        longitude = 360 * x
    }
    
    /// <summary>
    /// Converts pixel XY coordinates into tile XY coordinates of the tile containing
    /// the specified pixel.
    /// </summary>
    /// <param name="pixelX">Pixel X coordinate.</param>
    /// <param name="pixelY">Pixel Y coordinate.</param>
    /// <param name="tileX">Output parameter receiving the tile X coordinate.</param>
    /// <param name="tileY">Output parameter receiving the tile Y coordinate.</param>
    public static func PixelXYToTileXY(pixelX: Int, pixelY: Int, tileX: inout Int, tileY: inout Int) -> Void {
        tileX = pixelX / 256
        tileY = pixelY / 256
    }
    
    /// <summary>
    /// Converts tile XY coordinates into pixel XY coordinates of the upper-left pixel
    /// of the specified tile.
    /// </summary>
    /// <param name="tileX">Tile X coordinate.</param>
    /// <param name="tileY">Tile Y coordinate.</param>
    /// <param name="pixelX">Output parameter receiving the pixel X coordinate.</param>
    /// <param name="pixelY">Output parameter receiving the pixel Y coordinate.</param>
    public static func TileXYToPixelXY(tileX: Int, tileY: Int, pixelX: inout Int, pixelY: inout Int) -> Void {
        pixelX = tileX * 256
        pixelY = tileY * 256
    }
    
    /// <summary>
    /// Converts tile XY coordinates into a QuadKey at a specified level of detail.
    /// </summary>
    /// <param name="tileX">Tile X coordinate.</param>
    /// <param name="tileY">Tile Y coordinate.</param>
    /// <param name="levelOfDetail">Level of detail, from 1 (lowest detail)
    /// to 23 (highest detail).</param>
    /// <returns>A string containing the QuadKey.</returns>
    public static func TileXYToQuadKey(tileX: Int, tileY: Int, levelOfDetail: Int = QuadKey.levelOfDetail) -> String {
        Log(tileX)
        Log(tileY)
        Log(levelOfDetail)
        var quadKey = ""
        //        for (int i = levelOfDetail; i > 0; i--) {
        for i in (1...levelOfDetail).reversed() {
            Log(i)
            //            var digit: Character = "0"
            var digit = UnicodeScalar("0").value
            Log(digit)  //48 decimal
            let mask: Int = 1 << (i - 1)
            if ((tileX & mask) != 0) {
                digit += 1
            }
            if ((tileY & mask) != 0) {
                digit += 1
                digit += 1
            }
            Log(digit)
            //quadKey += digit
            //            quadKey.append(String(digit))
            if let unicode = UnicodeScalar(digit) {
                Log(unicode)
                quadKey.unicodeScalars.append(contentsOf: [unicode])
                Log(quadKey)
            }
            Log()
        }
        Log(quadKey)
        return quadKey
    }
    
    /// <summary>
    /// Converts a QuadKey into tile XY coordinates.
    /// </summary>
    /// <param name="quadKey">QuadKey of the tile.</param>
    /// <param name="tileX">Output parameter receiving the tile X coordinate.</param>
    /// <param name="tileY">Output parameter receiving the tile Y coordinate.</param>
    /// <param name="levelOfDetail">Output parameter receiving the level of detail.</param>
    enum QuadKeyError: Error {
        case invalidDigit   //("Invalid QuadKey digit sequence.")
    }
    public static func QuadKeyToTileXY(quadKey: String, tileX: inout Int, tileY: inout Int, levelOfDetail: inout Int) throws -> Void {
        tileX = 0
        tileY = 0
        levelOfDetail = quadKey.count
        //        for (int i = levelOfDetail; i > 0; i--) {
        for i in (1...levelOfDetail).reversed() {
            let mask: Int = 1 << (i - 1)
            //switch (quadKey[levelOfDetail - i])
            let quadKeyIndex = quadKey.index(quadKey.endIndex, offsetBy: -(i))
            switch (quadKey[quadKeyIndex]) {
            case "0": break
                //                break
            case "1":
                tileX |= mask
                //                break
            case "2":
                tileY |= mask
                //                break
            case "3":
                tileX |= mask
                tileY |= mask
                //                break
            default:
                throw QuadKeyError.invalidDigit
            }
        }
    }

    /*
     Transform LatLong to QuadKey
     */
    public func transform(latlong: CLLocationCoordinate2D) -> String {
        //let latitude: Double = 36.292
        //let longitude: Double = 120.325
        //let level = 20  //←これが文字数となる
        var pixelX: Int = 0
        var pixelY: Int = 0
        var tileX: Int = 0
        var tileY: Int = 0
        QuadKey.LatLongToPixelXY(latitude: latlong.latitude, longitude: latlong.longitude, pixelX: &pixelX, pixelY: &pixelY)
        QuadKey.PixelXYToTileXY(pixelX: pixelX, pixelY: pixelY, tileX: &tileX, tileY: &tileY)
        let quadKeyString = QuadKey.TileXYToQuadKey(tileX: tileX, tileY: tileY)
        return quadKeyString
    }

    /*
     GPS Manager
     */
    var gpsManager: CLLocationManager = CLLocationManager()
    @Published public var latlong: CLLocationCoordinate2D?
    @Published public var bornedLatLongUpdated = false
    
    override public init() {
        super.init()
        self.gpsManager.delegate = self
    }
    public func fetchCurrentLatlong() {
        requestLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        requestLocation()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.latlong = locations.first?.coordinate
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Log(error)
    }
    
    private func requestLocation() {
        if (self.gpsManager.authorizationStatus == .authorizedWhenInUse) {
            self.gpsManager.requestLocation()
        }
    }
    
    /*
     Map
     */
    @objc public func longPressedAction(_ gestureRecognizer: UIGestureRecognizer) {
        /*
         Get LatLong on Pressing Point.
         */
        guard let map = gestureRecognizer.view as? MKMapView else {
            return
        }
        let touchPoint = gestureRecognizer.location(in: gestureRecognizer.view)
        let newCoordinates = map.convert(touchPoint, toCoordinateFrom: gestureRecognizer.view)
        self.latlong = newCoordinates
        
        /*
         Make Annotation
         */
        //        let annotation = PinAnnotation()
        let annotation = MKPointAnnotation()
        annotation.coordinate = newCoordinates
        map.addAnnotation(annotation)
    }

}
