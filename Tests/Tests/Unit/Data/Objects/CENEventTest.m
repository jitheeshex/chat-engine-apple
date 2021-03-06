/**
 * @author Serhii Mamontov
 * @copyright © 2009-2018 PubNub, Inc.
 */
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <CENChatEngine/CENChatEngine+ChatPrivate.h>
#import <CENChatEngine/CENEventEmitter+Private.h>
#import <CENChatEngine/CENChatEngine+Publish.h>
#import <CENChatEngine/CENChat+Interface.h>
#import <CENChatEngine/CENObject+Private.h>
#import <CENChatEngine/CENEvent+Private.h>
#import <CENChatEngine/CENChat+Private.h>
#import <CENChatEngine/CENUser+Private.h>
#import <CENChatEngine/ChatEngine.h>
#import "CENTestCase.h"


@interface CENEventTest : CENTestCase


#pragma mark - Information

@property (nonatomic, nullable, weak) CENChatEngine *client;
@property (nonatomic, nullable, weak) CENChatEngine *clientMock;

@property (nonatomic, nullable, strong) CENEvent *event;
@property (nonatomic, nullable, strong) CENChat *chat;


#pragma mark -


@end


#pragma mark - Tests

@implementation CENEventTest


#pragma mark - Setup / Tear down

- (BOOL)shouldSetupVCR {
    
    return NO;
}

- (void)setUp {
    
    [super setUp];
    
    self.client = [self chatEngineWithConfiguration:[CENConfiguration configurationWithPublishKey:@"test-36" subscribeKey:@"test-36"]];
    self.clientMock = [self partialMockForObject:self.client];
    CENMe *user = [CENMe userWithUUID:@"tester" state:@{} chatEngine:self.client];
    self.chat = [CENChat chatWithName:@"test-chat" namespace:@"global-ns" group:CENChatGroup.custom private:NO metaData:@{} chatEngine:self.client];
    
    OCMStub([self.clientMock fetchParticipantsForChat:[OCMArg any]]).andDo(nil);
    OCMStub([self.clientMock me]).andReturn(user);
    
    self.event = [CENEvent eventWithName:@"test-event" chat:self.chat chatEngine:self.client];
}

- (void)tearDown {

    [self.event destruct];
    self.event = nil;
    
    [self.chat destruct];
    self.chat = nil;
    
    [super tearDown];
}


#pragma mark - Tests :: Constructor

- (void)testConstructor_ShouldCreateInstance {
    
    XCTAssertNotNil(self.event);
}


#pragma mark - Tests :: publish

- (void)testPublish_ShouldPublishPayload {
    
    NSDictionary *expectedData = @{ @"test": @"data", CENEventData.event: @"test-event" };
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSDictionary *dataForPublish = @{ @"test": @"data" };
    __block BOOL handlerCalled = NO;
    
    OCMExpect([self.clientMock publishStorable:YES event:self.event toChannel:self.event.channel withData:expectedData completion:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            handlerCalled = YES;
            
            dispatch_semaphore_signal(semaphore);
        });
    
    [self.event publish:[dataForPublish mutableCopy]];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.testCompletionDelay * NSEC_PER_SEC)));
    OCMVerifyAll((id)self.clientMock);
    XCTAssertTrue(handlerCalled);
}

- (void)testPublish_ShouldAddEventPublishTimetoken {
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSMutableDictionary *dataForPublish = [NSMutableDictionary dictionaryWithDictionary:@{ @"test": @"data" }];
    NSNumber *expectedTimetoken = @1234567890;
    __block BOOL handlerCalled = NO;
    
    OCMStub([self.clientMock publishStorable:YES event:[OCMArg any] toChannel:[OCMArg any] withData:[OCMArg any] completion:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            void(^handlerBlock)(NSNumber *) = nil;
            handlerCalled = YES;
            
            [invocation getArgument:&handlerBlock atIndex:6];

            handlerBlock(expectedTimetoken);
            dispatch_semaphore_signal(semaphore);
        });
    
    [self.event publish:dataForPublish];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25f * NSEC_PER_SEC)));
    XCTAssertNotNil(dataForPublish[CENEventData.timetoken]);
    XCTAssertEqual([(NSNumber *)dataForPublish[CENEventData.timetoken] compare:expectedTimetoken], NSOrderedSame);
    XCTAssertTrue(handlerCalled);
}

- (void)testPublish_ShouldPublishWithOutStoringInHistory_WhenSystemEventPublished {
    
    CENEvent *systemEvent = [CENEvent eventWithName:@"$.system.something" chat:self.chat chatEngine:self.clientMock];
    NSMutableDictionary *dataForPublish = [NSMutableDictionary dictionaryWithDictionary:@{ @"test": @"data" }];
    
    OCMExpect([self.clientMock publishStorable:NO event:systemEvent toChannel:systemEvent.channel withData:[OCMArg any] completion:[OCMArg any]]);
    
    [systemEvent publish:dataForPublish];
    
    OCMVerifyAll((id)self.clientMock);
}

- (void)testPublish_ShouldEmitEvent_WhenPublishCompleted {
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSMutableDictionary *dataForPublish = [NSMutableDictionary dictionaryWithDictionary:@{ @"test": @"data" }];
    NSNumber *expectedTimetoken = @1234567890;
    __block BOOL handlerCalled = NO;
    
    OCMStub([self.clientMock publishStorable:YES event:[OCMArg any] toChannel:[OCMArg any] withData:[OCMArg any] completion:[OCMArg any]])
        .andDo(^(NSInvocation *invocation) {
            void(^handlerBlock)(NSNumber *) = nil;
            [invocation getArgument:&handlerBlock atIndex:6];
            
            handlerBlock(expectedTimetoken);
        });
    
    [self.event handleEventOnce:@"$.emitted" withHandlerBlock:^(NSDictionary *payload) {
        handlerCalled = YES;
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    [self.event publish:dataForPublish];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.testCompletionDelay * NSEC_PER_SEC)));
    XCTAssertTrue(handlerCalled);
}


#pragma mark - Tests :: channel

- (void)testChannel_ShouldEqualToChannelOfChatPassedToConstructor {
    
    XCTAssertEqualObjects(self.event.channel, self.chat.channel);
}


#pragma mark - Tests :: event

- (void)testEvent_ShouldEqualToEventPassedToConstructor {
    
    XCTAssertEqualObjects(self.event.event, @"test-event");
}


#pragma mark - Tests :: chat

- (void)testChat_ShouldEqualToChatPassedToConstructor {
    
    XCTAssertEqual(self.event.chat, self.chat);
}


#pragma mark - Tests :: description

- (void)testDescription_ShouldProvideInstanceDescription {
    
    NSString *description = [self.event description];
    
    XCTAssertNotNil(description);
    XCTAssertGreaterThan(description.length, 0);
}

#pragma mark -


@end
