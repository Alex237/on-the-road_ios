//
//  TBMapzenRoutingResultLeg.m
//  TBMapzenRouting
//
//  Created by Jesse Crocker on 7/19/16.
//
//

#import <CoreLocation/CoreLocation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "TBMapzenRoutingResultLeg.h"

@interface TBMapzenRoutingResultLeg ()

@property (nonatomic, strong, nonnull) NSArray <TBMapzenRoutingResultManeuver*>* maneuvers;
@property (nonatomic, assign) NSUInteger coordinateCount;
@property (nonatomic, assign, nullable) CLLocationCoordinate2D *coordinates;

@end


@implementation TBMapzenRoutingResultLeg


+ (instancetype _Nullable)legFromDictionary:(NSDictionary * _Nonnull)response {
  TBMapzenRoutingResultLeg *leg = [[TBMapzenRoutingResultLeg alloc] init];
  leg.length = [response[@"summary"][@"length"] doubleValue];
  leg.time = [response[@"summary"][@"time"] doubleValue];
  NSMutableArray *maneuvers = [NSMutableArray arrayWithCapacity:[(NSArray*)response[@"maneuvers"] count]];
  for(NSDictionary *maneuver in response[@"maneuvers"]) {
    [maneuvers addObject:[TBMapzenRoutingResultManeuver maneuverFromDictionary:maneuver]];
  }
  leg.maneuvers = maneuvers;
  leg.coordinates = [TBMapzenRoutingResultLeg decodePolyline:response[@"shape"]
                                             length:&leg->_coordinateCount];
  
  return leg;
}


- (NSString * _Nonnull)description {
  return [NSString stringWithFormat:@"<%@: %p> length:%f time:%f maneuvers:%lu coordinates:%lu",
          NSStringFromClass([self class]), self,
          self.length, self.time,
          (unsigned long)self.maneuvers.count, (unsigned long)self.coordinateCount];
}


- (void)dealloc {
  free(self.coordinates);
}


+ (CLLocationCoordinate2D*)decodePolyline:(NSString*)polyline length:(NSUInteger*)outputLength {
  const char *bytes = [polyline UTF8String];
  NSUInteger length = [polyline lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  
  NSUInteger allocCount = length/4;
  CLLocationCoordinate2D *coords = calloc(allocCount, sizeof(CLLocationCoordinate2D));
  
  NSUInteger idx = 0;
  NSUInteger coordIdx = 0;
  
  CGFloat latitude = 0;
  CGFloat longitude = 0;
  while (idx < length) {
    char byte = 0;
    int res = 0;
    char shift = 0;
    
    do {
      byte = bytes[idx++] - 63;
      res |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);
    
    float deltaLat = ((res & 1) ? ~(res >> 1) : (res >> 1));
    latitude += deltaLat;
    
    shift = 0;
    res = 0;
    
    do {
      byte = bytes[idx++] - 0x3F;
      res |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);
    
    float deltaLon = ((res & 1) ? ~(res >> 1) : (res >> 1));
    longitude += deltaLon;
    
    coords[coordIdx++] = CLLocationCoordinate2DMake(latitude * 1E-6, longitude * 1E-6);
    
    if (coordIdx == allocCount) {
      allocCount += 10;
      coords = realloc(coords, allocCount * sizeof(CLLocationCoordinate2D));
    }
  }
  
  *outputLength = coordIdx;
  return coords;
}


@end
