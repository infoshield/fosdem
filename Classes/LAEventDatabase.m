//
//  LAEventDatabase.m
//  fosdem
//
//  Created by Leon on 9/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "LAEventDatabase.h"


@implementation LAEventDatabase


@synthesize events, eventsUserData;

static LAEventDatabase *mainEventsDatabase = nil;

+ (LAEventDatabase *) sharedEventsDatabase
{
	if(mainEventsDatabase == nil) {
        //NSLog(@"Loading event DB");
        /*// Try to load from the resource bundle first
         NSDictionary *eventsDictionary = [NSDictionary dictionaryWithContentsOfFile: [self eventsDatabaseLocation]];*/
        NSData *eventXMLData = [NSData dataWithContentsOfFile: [self eventDatabaseLocation]];
        if (eventXMLData != nil) {
            mainEventsDatabase = [[LAEventDatabase alloc] initWithData: eventXMLData];
        }
        else {
            mainEventsDatabase = [[LAEventDatabase alloc] init];
        }
    }
    return mainEventsDatabase;	
}


- (LAEventDatabase*) init {
    if (self = [super init]) {
        events = [[NSMutableArray alloc] init];
		//stared = [[NSMutableArray alloc] init];
        eventsOnDayCache = [[NSMutableDictionary alloc] init];
		
		[[NSNotificationCenter defaultCenter] addObserver: self 
												 selector: @selector(eventUpdated:) 
													 name: @"LAEventUpdated"  
												   object: nil];
        
        NSMutableDictionary *userDataDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile: [[self class] userDataFileLocation]];
        if (!userDataDictionary) {
            userDataDictionary = [[NSMutableDictionary alloc] init];
        }
		[self setEventsUserData: userDataDictionary];
        
    }
    return self;
}

- (LAEventDatabase *) initWithData: (NSData *) xmlData {
    if (self = [self init]) {
        LAEventsXMLParser *xmlParser = [[LAEventsXMLParser alloc] initWithData: xmlData delegate: self];
        [xmlParser parse];
    }
    return self;
}

- (void) parser: (LAEventsXMLParser *) parser foundEvent: (LAEvent *) event {
    [events addObject: event];
    [self updateEventWithUserData: event];
}

- (void) parserFinishedParsing:(LAEventsXMLParser *)parser {
    [parser release];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"LAEventDatabaseUpdated" object: self];
    
}

- (void) parserDidFinishSchedule:(LAEventsXMLParser *)parser {
    
}

- (NSArray *) uniqueDays {
    
    if (cachedUniqueDays != nil) {
        return cachedUniqueDays;
    }
    
    NSEnumerator *eventsEnumerator = [events objectEnumerator];
    LAEvent *currentEvent;
    
    NSMutableArray *uniqueDays = [[NSMutableArray alloc] init];
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    
    while (currentEvent = [eventsEnumerator nextObject]) {
        NSDateComponents *currentEventDateComponents = [calendar components: (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate: [currentEvent startDate]];
        
        // We have the date of the event. Now we have to loop through the existing unique dates to see if there already is a date like that.
        NSEnumerator *uniqueDaysEnumerator = [uniqueDays objectEnumerator];
        NSDate *currentUniqueDay;
        
        BOOL foundMatchingDay = NO;
        
        while (currentUniqueDay = [uniqueDaysEnumerator nextObject]) {
            NSDateComponents *uniqueDayDateComponents = [calendar components: (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate: currentUniqueDay];
            // Does the current looped unique day match the one we have from the event?
            if([uniqueDayDateComponents day] == [currentEventDateComponents day] && \
               [uniqueDayDateComponents month] == [currentEventDateComponents month] && \
               [uniqueDayDateComponents year] == [currentEventDateComponents year]) {
                // Our event does not have a unique date
                foundMatchingDay = YES;
                break;
                
            }
        }
        
        // If the day was already in the uniqueDays, we would have found it by now
        if (!foundMatchingDay) {
            // The event day is unique! Let's insert it!
            // Same shit, different day
            [currentEventDateComponents setSecond: 0];
            [currentEventDateComponents setMinute: 0];
            [currentEventDateComponents setHour: 0];
            
            [uniqueDays addObject: [calendar dateFromComponents: currentEventDateComponents]];
        }
    }
    
    cachedUniqueDays = uniqueDays;
    return uniqueDays;
}

- (NSArray *) eventsOnDay: (NSDate *) dayDate {
	
	// Not really the way to do it but it probably works fine
	if ([eventsOnDayCache objectForKey: dayDate] != nil) {
		return [eventsOnDayCache objectForKey: dayDate];
	}
	
    NSEnumerator *eventsEnumerator = [events objectEnumerator];
    LAEvent *currentEvent;
    
    NSMutableArray *eventsOnDay = [NSMutableArray array];
    
    NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
    
    while (currentEvent = [eventsEnumerator nextObject]) {
        NSDateComponents *currentEventDateComponents = [calendar components: (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate: [currentEvent startDate]];
        NSDateComponents *eventDateComponents = [calendar components: (NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit) fromDate: dayDate];
        
        if([eventDateComponents day] == [currentEventDateComponents day] && \
           [eventDateComponents month] == [currentEventDateComponents month] && \
           [eventDateComponents year] == [currentEventDateComponents year]) {
            // Obviously the event is on the same day
            [eventsOnDay addObject: currentEvent];
        }
    }
	
	[eventsOnDayCache setObject: eventsOnDay forKey: dayDate];
	//NSLog(@"BOOM");
    return eventsOnDay;
}

-(NSArray *) tracks {
	
    if (tracksCache != nil) {
        return tracksCache;
    }
    
	NSEnumerator *eventsEnumerator = [events objectEnumerator];
    LAEvent *currentEvent;
    
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
	
	while (currentEvent = [eventsEnumerator nextObject]){
        
		if (![tracks containsObject: [NSString stringWithFormat: @"%@", [currentEvent track]]]) {
			[tracks addObject: [NSString stringWithFormat: @"%@", [currentEvent track]]];
		}
        
	}
	
    tracksCache = tracks;
    
	return tracks;
    
}

-(NSArray *) eventsForTrack: (NSString*) trackName {
	
	NSEnumerator *eventsEnumerator = [events objectEnumerator];
    LAEvent *currentEvent;
    
    NSMutableArray *eventsForTrackName = [NSMutableArray array];
	
	while (currentEvent = [eventsEnumerator nextObject]){
		
		if ([[currentEvent track] isEqualToString: trackName]) {
			[eventsForTrackName addObject: currentEvent];
		}
		
	}
    
	return eventsForTrackName;
	
}

+ (NSString *) eventDatabaseLocation {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *cachesDirectory = [paths objectAtIndex:0];
    NSString *cacheFileLocation = [cachesDirectory stringByAppendingPathComponent:@"fosdem_schedule.xml"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: cacheFileLocation]) {
        return cacheFileLocation;
    }
    
    NSString *resourcesDirectory = [[NSBundle mainBundle] bundlePath];
    NSString *resourceFileLocation = [resourcesDirectory stringByAppendingPathComponent:@"fosdem_schedule.xml"];
    return resourceFileLocation;
    
}


+ (NSString *) userDataFileLocation {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *userDataFileLocation = [documentDirectory stringByAppendingPathComponent:@"userData.plist"];
    
    return userDataFileLocation;
}


- (NSMutableDictionary *) userDataForEventWithIdentifier: (NSString *) identifier {
	if ([eventsUserData objectForKey: identifier] == nil) {
		[eventsUserData setObject: [NSMutableDictionary dictionary] forKey: identifier];
	}
	return [eventsUserData objectForKey: identifier];
}

- (void) eventUpdated: (NSNotification *) notification {
    NSDictionary *infoDict = [notification userInfo];
    NSMutableDictionary *userData = [self userDataForEventWithIdentifier: [infoDict objectForKey: @"identifier"]];
    
    if ([infoDict objectForKey: @"starred"]) {
        // Change in the starred property
        [userData setObject: [infoDict objectForKey: @"starred"] forKey: @"starred"];
    }
    
    [[self eventsUserData] writeToFile: [[self class] userDataFileLocation] atomically: NO];
}

- (void) updateEventWithUserData: (LAEvent *) event {
    NSMutableDictionary *userData = [self userDataForEventWithIdentifier: [event identifier]];
    
    if ([userData objectForKey: @"starred"]) {
        [event setStarred: [(NSNumber *)[userData objectForKey: @"starred"] boolValue]];
    }
}

- (void) dealloc {
    [events release];
    [super dealloc];
}

@end
