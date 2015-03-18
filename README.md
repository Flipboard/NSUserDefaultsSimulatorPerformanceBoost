# NSUserDefaults+SimulatorPerformance

## Purpose

In iOS 8, `NSUserDefaults` read performance in the simulator declined significantly. For apps that read from `NSUserDefaults` often, this causes sluggishness while debugging and a misleading discrepancy between the real device and the simulator.

This project includes an `NSUserDefaults` category named `NSUserDefaults+SimulatorPerformance` that dramatically improves read performance in the simulator by adding a man-in-the-middle write-through cache in memory. It does so by swizzling out all of `NSUserDefaults`' setters and getters and replacing them with `fl_`-prefixed methods that correctly populate and update a cache.

## Demo Project

A demo project is provided to illustrate the performance improvements this project has.

![](http://cl.ly/image/1I2N2j2g0J3K/NSUserDefaultsDemoSmall.png)

It includes three commands:

- **Write** will write a set of entries into `NSUserDefaults`. The count of entries written is determined by the slider below.
- **Read (Slow)** will read a set of entries from `NSUserDefaults` using the default uncached implementation of `-setObject:forKey:`. The count of entries read is determined by the slider below.
- **Read (Fast)** will read a set of entries from `NSUserDefaults` using the swizzled, cached implementation of `-setObject:forKey:`. The count of entries read is determined by the slider below.

Note that the first time **Read (Fast)** is tapped it will likely have performance similar to **Read (Slow)** because the cached values for the entries being read aren't updated yet. On subsequent uses of the **Read (Fast)** button you should see significant performance gains.


## Installation

Using this project is easy! All you have to do to start using it is include the `NSUserDefaults+Simulator` .h/.m pair in your project, that's it. This category automatically swizzles out `NSUserDefaults`' methods when the class is loaded if `TARGET_IPHONE_SIMULATOR` is on. If this is loaded, you'll see the following log at launch time.

![](http://cl.ly/image/2n3E3l1S1Q2U/nsuserdefaultsperflaunchlog.png)

## Extensions

**Important Note:**

Because use of `NSUserDefaults+SimulatorPerformance` adds a level of indirection between you and the actual values stored in `NSUserDefaults`, it may cause issues when debugging extensions.

Writes from an app to an instance of `NSUserDefaults` that's shared with an extension will go through synchronously since the write methods in this category are write-through.

![](http://cl.ly/image/0f1x3b2z3h28/NSUserDefaultsDiagramsExtension1.jpg)


However, values written by an extension to an instance of `NSUserDefaults` shared with an app may be inconsistent when read by that app if a cached value exists. This is because writes to `NSUserDefaults` in other processes will not update the in-memory cache this category uses.

![](http://cl.ly/image/37210e2K0L23/NSUserDefaultsDiagramsExtension2.jpg)

It is highly recommended that if you're going to be testing an extension that you disable this category.

## Contributing

Contributions to this project are very welcome. Contributors to this repository must accept Flipboard’s Apache-style [Individual Contributor License Agreement (CLA)](https://docs.google.com/forms/d/1gh9y6_i8xFn6pA15PqFeye19VqasuI9-bGp_e0owy74/viewform) before any changes can be merged.

## License

This project is available under the BSD 3-clause license. See the [LICENSE file](./LICENSE) for more info.