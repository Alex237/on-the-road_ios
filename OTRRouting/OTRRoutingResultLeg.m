//
//  OTRRoutingResultLeg.m
//  on-the-road_ios
//
//  Based upon the work in OTRRouting created by Jesse Crocker
//
//

#import "OTRRoutingResultLeg.h"
#import "OTRRoutingPolylineUtils.h"

@interface OTRRoutingResultLeg ()

@property (nonatomic, strong, nonnull) NSArray <OTRRoutingResultManeuver*>* maneuvers;
@property (nonatomic, assign) NSUInteger coordinateCount;
@property (nonatomic, assign, nullable) OTRGeoPoint *coordinates;
@property (nonatomic, assign, nullable) CLLocationCoordinate2D *locations;

@end


@implementation OTRRoutingResultLeg


+ (instancetype _Nullable)legFromDictionary:(NSDictionary * _Nonnull)response {
  OTRRoutingResultLeg *leg = [[OTRRoutingResultLeg alloc] init];
  leg.length = (CGFloat) [response[@"summary"][@"length"] doubleValue];
  leg.time = (CGFloat) [response[@"summary"][@"time"] doubleValue];
  NSMutableArray *maneuvers = [NSMutableArray arrayWithCapacity:[(NSArray*)response[@"maneuvers"] count]];
  for(NSDictionary *maneuver in response[@"maneuvers"]) {
    [maneuvers addObject:[OTRRoutingResultManeuver maneuverFromDictionary:maneuver]];
  }
  leg.maneuvers = maneuvers;
  leg.coordinates = [OTRRoutingPolylineUtils decodePolyline:response[@"shape"]
                                             length:&leg->_coordinateCount];
  leg.locations = [OTRRoutingPolylineUtils decodeLocationPolyline:response[@"shape"]
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


@end
