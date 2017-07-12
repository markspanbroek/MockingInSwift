/*:

To Kill a Mocking Bird
======================
## Mocking in Swift ##

Mocking in Swift is hard. Mocking frameworks traditionally depend on a number of language features to do their work. They typically need to ensure that a mock object is interchangeable with a real object and they need to intercept method calls to be able to record the fact that they were called.

So in languages like Javascript or Ruby which have no compile time type checking and allow any method call to be intercepted, writing a mocking framework is almost a trivial exercise. With Swifts heavy static type checking and no way to intercept method calls, mocking becomes troublesome.

This explains the absence of mocking frameworks in Swift. But not all is lost. We will expand upon a number of techniques that, although they are a bit more cumbersome than simply using a mocking framework, will allow you to create mocks in your tests.

### Your own classes ###

There is a relatively easy way to mock classes in Swift when they are under your control. Let’s assume that we are writing an app that talks to a backend using a class called ‘Backend’:

*/

class Backend {
    func storeItem(item: Item) {
        // makes http POST call
    }
}

class Item {}

/*:

If we wish to mock this class then all we have to do is extract a protocol, and ensure that we use the protocol instead of the class throughout the app:

*/

protocol BackendType {
    func storeItem(item: Item)
}

extension Backend : BackendType {}

/*:

In your tests you can now introduce a mock variant of the Backend by providing a second implementation of the BackendType protocol:

*/

class BackendMock : BackendType {
    var latestItem: Item?

    func storeItem(item: Item) {
        latestItem = item
    }
}

/*:

Notice that it now become easy to introduce a method that checks that the storeItem method was called with the correct parameter:

*/

import XCTest

extension BackendMock {
    func verifyLatestItemEquals(expected: Item) {
        XCTAssertTrue(latestItem === expected)
    }
}

/*:

For more about introducing protocols in your code and why that is such a good idea, I refer you to the excellent [WWDC video about Protocol Oriented Programming in Swift](https://developer.apple.com/videos/play/wwdc2015/408/).

### Third party classes ###

Things become a bit more complex when the classes that you want to mock are not under your control. For instance when you want to mock a class from a system library.

Let’s assume that we wish to use Apple’s Core Bluetooth framework. It contains a class called CBCentralManager, which has a method for connecting to a Bluetooth peripheral:

```swift
    func connect(peripheral: CBPeripheral, options: [String : AnyObject]?)
```

If we were to apply the same strategy as before, we would extract a protocol from CBPeripheral and change the signature of the connect method such that the type of the peripheral parameter is no longer a class but a protocol.

Because both the CBCentralManager class and the CBPeripheral class are part of Apple’s framework, we cannot do that.

Luckily there are two strategies that we can apply.

### Wrapping ###

A standard technique when dealing with hard-to-mock classes is to wrap them. In Swift we can use a slightly nicer variation using extensions.

In our Bluetooth example we would first extract a protocol for CBPeripheral:

*/

import CoreBluetooth

protocol CBPeripheralType: class {}

extension CBPeripheral: CBPeripheralType {}

/*:

Then we extract a protocol for CBCentralManager where we take care to replace the occurrence of CBPeripheral with CBPeripheralType:

*/

protocol CBCentralManagerType {
    func connect(peripheral: CBPeripheralType, options: [String: AnyObject]?)
}

/*:

By wrapping the connect method we ensure that CBCentralManager conforms to the new protocol:

*/

extension CBCentralManager: CBCentralManagerType {
    func connect(peripheral: CBPeripheralType, options: [String: AnyObject]?) {
        if let realPeripheral = peripheral as? CBPeripheral {
            connect(realPeripheral, options: options)
        }
    }
}

/*:

Now we are free to introduce mocks for both CBCentralManager and CBPeripheral:

*/

class CBPeripheralMock: CBPeripheralType {}

class CBCentralManagerMock: CBCentralManagerType {
    var latestPeripheral: CBPeripheralType?

    func connect(peripheral: CBPeripheralType, options: [String : AnyObject]?) {
            latestPeripheral = peripheral
    }
}

/*:

And we can create a method for checking that the correct peripheral was connected:

*/

extension CBCentralManagerMock {
    func verifyLatestPeripheralEquals(expected: CBPeripheralType) {
        XCTAssertTrue(latestPeripheral === expected)
    }
}

/*:

### Cheating ###

Should you wish to avoid introducing protocols for all classes in a third-party framework then there’s another option. You can create your mocks in Objective-C using a mocking framework. This  could be considered cheating because it is not a pure Swift solution and it will not work for mocking pure Swift frameworks.

But sometimes cheating is a winning strategy.

Going back to our Bluetooth example, we will introduce a mock for CBPeripheral in Objective-C using the [OCMockito framework](https://github.com/jonreid/OCMockito):

 ```objective-c
    @import OCMockito;
    @import CoreBluetooth;

    @interface CBPeripheralMock: NSObject
    @property(readonly, nonatomic) CBPeripheral *mock;
    @end

    @implementation CBPeripheralMock

    - (instancetype)init
    {
        self = [super init];
        if (self) {
            _mock = mock(CBPeripheral.class);
        }
        return self;
    }
    @end
 ```

And also a mock for the CBCentralManager:

```objective-c
    @import OCMockito
    @import OCHamcrest;
    @import CoreBluetooth;

    @interface CBCentralManagerMock: NSObject
    @property(readonly, nonatomic) CBCentralManager *mock;
    @end

    @implementation CBCentralManagerMock
    - (instancetype)init {
        _mock = mock(CBCentralManagerMock.class)
    }

    - (void)verifyPeripheralEquals:(CBPeripheral *) expected  {
        [verify(self.mock) connectPeripheral:expected options:anything()]
    }
    @end
```
 
 Using this small Objective-C layer we are now free to write the rest of the test in Swift.

 Notice that the mock class does not inherit from the class that it is mocking. Therefore it cannot be directly used in places where the real class is expected. In your tests you would use the mock property to get to the actual mock.
 ### Thanks ###

 Many thanks to my colleagues Berik, Derk & XiaoChen for exploring these solutions with me.
 
 Mark Spanbroek, 2016-08-04

*/
