/**
 * @author Serhii Mamontov
 * @copyright © 2009-2018 PubNub, Inc.
 */
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <CENChatEngine/CENChatEngine+PubNubPrivate.h>
#import <CENChatEngine/CENChatEngine+ChatPrivate.h>
#import <CENChatEngine/CENEventEmitter+Interface.h>
#import <CENChatEngine/CENChatEngine+UserPrivate.h>
#import <CENChatEngine/CENChatEngine+Private.h>
#import <CENChatEngine/CENChatEngine+Session.h>
#import <CENChatEngine/CENObject+Private.h>
#import <CENChatEngine/CENChat+Private.h>
#import <CENChatEngine/CENUser+Private.h>
#import <CENChatEngine/CENMe+Private.h>
#import <CENChatEngine/ChatEngine.h>
#import "CENTestCase.h"


@interface CENMeTest : CENTestCase


#pragma mark - Information

@property (nonatomic, nullable, weak) CENChatEngine *client;
@property (nonatomic, nullable, weak) CENChatEngine *clientMock;
@property (nonatomic, nullable, strong) CENMe *meWithOutState;
@property (nonatomic, nullable, strong) CENMe *meWithState;
@property (nonatomic, nullable, strong) CENChat *global;

#pragma mark -


@end


#pragma mark - Tests

@implementation CENMeTest


#pragma mark - Setup / Tear down

- (BOOL)shouldSetupVCR {
    
    return NO;
}

- (void)setUp {
    
    [super setUp];
    
    self.client = [self chatEngineWithConfiguration:[CENConfiguration configurationWithPublishKey:@"test-36" subscribeKey:@"test-36"]];
    self.clientMock = [self partialMockForObject:self.client];
    
    self.global = [self partialMockForObject:self.client.Chat().name(@"global").autoConnect(NO).create()];
    
    OCMStub([self.clientMock global]).andReturn(self.global);
    OCMStub([self.clientMock fetchParticipantsForChat:[OCMArg any]]).andDo(nil);
    OCMStub([self.clientMock createDirectChatForUser:[OCMArg any]])
        .andReturn(self.clientMock.Chat().name(@"chat-engine#user#tester#write.#direct").autoConnect(NO).create());
    OCMStub([self.clientMock createFeedChatForUser:[OCMArg any]])
        .andReturn(self.clientMock.Chat().name(@"chat-engine#user#tester#read.#feed").autoConnect(NO).create());
    
    self.meWithState = [CENMe userWithUUID:@"tester1" state:@{ @"test": @"state" } chatEngine:self.client];
    self.meWithOutState = [CENMe userWithUUID:@"tester2" state:@{} chatEngine:self.client];
    
    OCMStub([self.clientMock me]).andReturn(self.meWithOutState);
}

- (void)tearDown {

    [self.meWithOutState destruct];
    [self.meWithState destruct];
    self.meWithOutState = nil;
    self.meWithState = nil;
    
    [super tearDown];
}


#pragma mark - Tests :: session

- (void)testSession_ShouldRetrieveReferenceFromChatEngine {
    
    id expected = @{};
    OCMExpect([self.clientMock synchronizationSession]).andReturn(expected);
    
    XCTAssertEqualObjects(self.clientMock.me.session, expected);
    
    OCMVerifyAll((id)self.clientMock);
}


#pragma mark - Tests :: assignState

- (void)testAssignTest_ShouldChangeStateLocally {
    
    NSDictionary *expectedState = @{ @"test": @"state", @"success": @YES };
    id mePartialMock = [self partialMockForObject:self.meWithState];
    NSDictionary *state = @{ @"success": @YES };
    
    OCMExpect([[mePartialMock reject] fetchStoredStateWithCompletion:[OCMArg any]]);
    
    [self.meWithState assignState:state];
    
    OCMVerifyAll(mePartialMock);
    XCTAssertEqualObjects(self.meWithState.state, expectedState);
}


#pragma mark - Tests :: updateState

- (void)testUpdateState_ShouldChangeState {
    
    NSDictionary *expectedState = @{ @"fromRemote": @YES, @"success": @YES };
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSDictionary *state = @{ @"success": @YES };
    CENMe *expectedUser = self.meWithOutState;
    __block BOOL handlerCalled = NO;
    
    OCMStub([self.clientMock fetchUserState:self.meWithOutState withCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        void(^handlerBlock)(NSDictionary *) = nil;
        
        [invocation getArgument:&handlerBlock atIndex:3];
        handlerBlock(@{ @"fromRemote": @YES });
    });
    
    [self.clientMock handleEvent:@"$.state" withHandlerBlock:^(CENMe *me) {
        handlerCalled = YES;
        
        XCTAssertEqual(me, expectedUser);
        dispatch_semaphore_signal(semaphore);
    }];
    
    self.meWithOutState.update(state);
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.testCompletionDelay * NSEC_PER_SEC)));
    XCTAssertTrue(handlerCalled);
    XCTAssertEqualObjects(self.meWithOutState.state, expectedState);
}

- (void)testUpdateState_ShouldPropagateStateToRemoteUsers {
    
    NSDictionary *expectedState = @{ @"fromRemote": @YES, @"success": @YES };
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSDictionary *state = @{ @"success": @YES };
    __block BOOL handlerCalled = NO;
    
    OCMStub([self.clientMock fetchUserState:self.meWithOutState withCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        void(^handlerBlock)(NSDictionary *) = nil;
        
        [invocation getArgument:&handlerBlock atIndex:3];
        handlerBlock(@{ @"fromRemote": @YES });
    });
    
    OCMExpect([self.global setState:expectedState withCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        handlerCalled = YES;
        
        dispatch_semaphore_signal(semaphore);
    });
    
    self.meWithOutState.update(state);
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.testCompletionDelay * NSEC_PER_SEC)));
    OCMVerifyAll((id)self.global);
    XCTAssertTrue(handlerCalled);
}


#pragma mark - Tests :: description

- (void)testDescription_ShouldProvideInstanceDescription {
    
    NSString *description = [self.meWithState description];
    
    XCTAssertNotNil(description);
    XCTAssertGreaterThan(description.length, 0);
}


#pragma mark -


@end
