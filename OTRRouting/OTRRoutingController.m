//
//  OTRRoutingController.m
//  on-the-road_ios
//
//  Based upon the work in OTRRouting created by Jesse Crocker
//
//

#import "OTRRoutingController.h"
#import "OTRRoutingPolylineUtils.h"

@interface OTRRoutingController ()

@property (nonatomic, strong, nonnull) NSURLSession *urlSessionManager;

@end


@implementation OTRRoutingController

- (instancetype _Nonnull)init {
  return [self initWithSessionManager:[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]]];
}

- (instancetype _Nonnull)initWithSessionManager:(NSURLSession*  _Nonnull)session {
  self = [super init];
  self.baseUrl = @"https://valhalla.mapzen.com/";
  self.urlSessionManager = session;
  self.urlQueryComponents = [[NSMutableArray alloc] init];
  return self;
}


- (NSURLSessionDataTask * _Nullable)requestRouteWithLocations:(NSArray<OTRRoutingPoint*>* _Nonnull)locations
                                                 costingModel:(OTRRoutingCostingModel)costing
                                                costingOption:(NSDictionary<NSString*, NSObject*>* _Nullable)costingOptions
                                            directionsOptions:(NSDictionary<NSString*, NSObject*>* _Nullable)directionsOptions
                                                     callback:(void (^ _Nonnull)(OTRRoutingResult  * _Nullable result,
                                                             id _Nullable invalidationToken,
                                                             NSError * _Nullable error ))callback {
  if(locations.count < 2) {
    callback(nil, nil, [NSError errorWithDomain:@"OTRRoutingController"
                                           code:0
                                       userInfo:@{NSLocalizedDescriptionKey: @"Locations array must contain 2 or more locations"}]);
    return nil;
  }
  
  NSMutableDictionary *jsonParameters = [NSMutableDictionary dictionaryWithCapacity:2];
  jsonParameters[@"costing"] = [OTRRoutingTypes stringFromCostingModel:costing];
  jsonParameters[@"locations"] = [OTRRoutingController convertLocationsToDictionarys:locations];
  
  if(costingOptions) {
    if(![NSJSONSerialization isValidJSONObject:costingOptions]) {
      callback(nil, nil, [NSError errorWithDomain:@"OTRRoutingController"
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey: @"costingOptions is not a valid json object"}]);
      return nil;
    }
    jsonParameters[@"costing_options"] = costingOptions;
  }

  NSString *languageCode = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];

  if(!directionsOptions) {
    directionsOptions = @{@"language": languageCode};
  } else if (![directionsOptions.allKeys containsObject:@"language"]) {
    NSMutableDictionary *mutableOptions = [directionsOptions mutableCopy];
    mutableOptions[@"language"] = languageCode;
    directionsOptions = mutableOptions;
  }
  if(directionsOptions) {
    if (![NSJSONSerialization isValidJSONObject:directionsOptions]) {
      callback(nil, nil, [NSError errorWithDomain:@"OTRRoutingController"
                                             code:0
                                         userInfo:@{NSLocalizedDescriptionKey: @"directionsOptions is not a valid json object"}]);
      return nil;
    }
  }
  jsonParameters[@"directions_options"] = directionsOptions;

  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonParameters
                                                     options:0
                                                       error:nil];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  
  NSURLComponents *urlComponents = [NSURLComponents componentsWithString:self.baseUrl];
  urlComponents.path = @"/route";

  NSMutableArray *queryComponents = [[NSMutableArray alloc] init];
  [queryComponents addObject:[NSURLQueryItem queryItemWithName:@"json" value:jsonString]];
  //Adding the components to a newly created array avoids re-adding the same values multiple times and thus having weird issues later
  if (self.urlQueryComponents.count > 0) {
    [queryComponents addObjectsFromArray:self.urlQueryComponents];
  }

  // urlComponents.queryItems = queryComponents;
  
  NSURLSessionDataTask *task;
  task =
  [self.urlSessionManager dataTaskWithURL:urlComponents.URL
                        completionHandler:
   ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
     if(error || ((NSHTTPURLResponse*)response).statusCode != 200) {
       NSString *responseString;
       if(data) {
         responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
       }
       dispatch_async(dispatch_get_main_queue(), ^{
         callback(nil, task, [NSError errorWithDomain:@"OTRRoutingServerResponse"
                                                 code:((NSHTTPURLResponse*)response).statusCode
                                             userInfo:@{NSLocalizedDescriptionKey:responseString ?: @"unknown error"}]);
       });
     } else {
       NSError *error;
       NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                          options:0
                                                                            error:&error];
       if(error) {
         dispatch_async(dispatch_get_main_queue(), ^{
           callback(nil, nil, [NSError errorWithDomain:@"OTRRoutingServerResponse"
                                                  code:0
                                              userInfo:@{NSLocalizedDescriptionKey: @"response is not a valid json object"}]);
         });
       } else {
         OTRRoutingResult *result = [OTRRoutingController parseServerResponse:responseDictionary
                                                                                   task:task
                                                                                  error:&error];
         dispatch_async(dispatch_get_main_queue(), ^{
           callback(result, task, error);
         });
       }
     }
   }];
  [task resume];
  return task;
}

- (id _Nullable)requestMapMatchWithLocations:(CLLocationCoordinate2D* _Nonnull)locations
                                       count:(NSUInteger)coordinateCount
                                costingModel:(OTRRoutingCostingModel)costing
                                    callback:(void (^ _Nonnull)(OTRRoutingResult  * _Nullable result,
                                            id _Nullable invalidationToken,
                                            NSError * _Nullable error ))callback {
  return [self requestMapMatchJsonWithLocations:locations
                                          count:coordinateCount
                                   costingModel:costing
                                       callback:
 ^(NSData * _Nullable resultData, id  _Nullable invalidationToken, NSError * _Nullable error) {
     if(error) {
       dispatch_async(dispatch_get_main_queue(), ^{
           callback(nil, invalidationToken, error);
       });
     } else {
       NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:resultData
                                                                          options:0
                                                                            error:nil];
       OTRRoutingResult *result = [OTRRoutingController parseServerResponse:responseDictionary
                                                                                 task:invalidationToken
                                                                                error:&error];
       dispatch_async(dispatch_get_main_queue(), ^{
           callback(result, invalidationToken, error);
       });
     }
 }];
}

- (id _Nullable)requestMapMatchJsonWithLocations:(CLLocationCoordinate2D* _Nonnull)locations
                                           count:(NSUInteger)coordinateCount
                                    costingModel:(OTRRoutingCostingModel)costing
                                        callback:(void (^ _Nonnull)(NSData  * _Nullable resultData,
                                                id _Nullable invalidationToken,
                                                NSError * _Nullable error ))callback {
  if(coordinateCount < 2) {
    callback(nil, nil, [NSError errorWithDomain:@"OTRRoutingController"
                                           code:0
                                       userInfo:@{NSLocalizedDescriptionKey: @"Locations array must contain 2 or more locations"}]);
    return nil;
  }


  NSMutableDictionary *jsonParameters = [NSMutableDictionary dictionaryWithCapacity:3];
  jsonParameters[@"costing"] = [OTRRoutingTypes stringFromCostingModel:costing];
  jsonParameters[@"shape_match"] = @"map_snap";
  jsonParameters[@"search_radius"] = @(50);
  jsonParameters[@"sigma_z"] = @(20);
  jsonParameters[@"encoded_polyline"] = [OTRRoutingPolylineUtils encodePolylineForCoordinates:locations
                                                                                            length:coordinateCount];

  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonParameters
                                                     options:0
                                                       error:nil];

  NSURLComponents *urlComponents = [NSURLComponents componentsWithString:self.baseUrl];
  urlComponents.path = @"/trace_route";
  //urlComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"api_key" value:self.apiKey]];

  NSMutableURLRequest *requst = [NSMutableURLRequest requestWithURL:urlComponents.URL];
  [requst setHTTPMethod:@"POST"];
  [requst setHTTPBody:jsonData];

  NSURLSessionDataTask *task;
  task =
    [self.urlSessionManager dataTaskWithRequest:requst
                              completionHandler:
                                      ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                          if(error || ((NSHTTPURLResponse*)response).statusCode != 200) {
                                            NSString *responseString;
                                            if(data) {
                                              responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                            }
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                callback(nil, task, [NSError errorWithDomain:@"OTRRoutingServerResponse"
                                                                                        code:((NSHTTPURLResponse*)response).statusCode
                                                                                    userInfo:@{NSLocalizedDescriptionKey:responseString ?: @"unknown error"}]);
                                            });
                                          } else {
                                            NSError *error;
                                            NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                                                               options:0
                                                                                                                 error:&error];
                                            if(error) {
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  callback(nil, nil, [NSError errorWithDomain:@"OTRRoutingServerResponse"
                                                                                         code:0
                                                                                     userInfo:@{NSLocalizedDescriptionKey: @"response is not a valid json object"}]);
                                              });
                                            } else {
                                              dispatch_async(dispatch_get_main_queue(), ^{
                                                  callback(data, task, error);
                                              });
                                            }
                                          }
                                      }];
  [task resume];
  return task;
}


- (void)cancelRoutingRequest:(NSURLSessionDataTask *)requestToken {
    [requestToken cancel];
}


+ (OTRRoutingResult* _Nullable)parseServerResponse:(NSDictionary * _Nonnull)response
                                                   task:(NSURLSessionDataTask * _Nonnull)task
                                                  error:(NSError * _Nullable *)error {
  OTRRoutingResult *result = [OTRRoutingResult resultFromResponse:response];
  return result;
}


+ (NSArray <NSDictionary*> *)convertLocationsToDictionarys:(NSArray<OTRRoutingPoint*>* _Nonnull)locations {
  NSMutableArray *output = [NSMutableArray arrayWithCapacity:locations.count];
  for(OTRRoutingPoint *point in locations) {
    [output addObject:[point asDictionary]];
  }
  return output;
}


@end
