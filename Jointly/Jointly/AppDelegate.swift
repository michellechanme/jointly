//
//  AppDelegate.swift
//  Jointly
//
//  Created by Michelle Chan on 7/9/15.
//  Copyright (c) 2015 Michelle Chan. All rights reserved.
//

import UIKit
import Fabric
import DigitsKit
import Parse
import Bolts
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        ScreenLockObserver.sharedObserver().applicationDidFinishLaunching()
        
        Parse.setApplicationId("F4DIGtRF8bJDFJR3Yfpzl1VQFQv2N9s4OsbZRerW", clientKey: "9vWOLwceVNcln6l5Qf6kjA1gg6sMoU7ik9wmMeHQ")
        
        // Setup push notifications
        let userNotificationTypes = (UIUserNotificationType.Alert |  UIUserNotificationType.Badge |  UIUserNotificationType.Sound);
        let settings = UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
        application.registerUserNotificationSettings(settings)
        application.registerForRemoteNotifications()
        
        // Override point for customization after application launch.
        Fabric.with([Digits()])
        
        let digitsAppearance = DGTAppearance()
        
        func UIColorFromRGB(rgbValue: UInt) -> UIColor {
            return UIColor(
                red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                alpha: CGFloat(1.0)
            )
        }
        
        UINavigationBar.appearance().barTintColor = UIColorFromRGB(0x6B94C8)
        UINavigationBar.appearance().tintColor = UIColor.whiteColor()
        var navigationBarAppearace = UINavigationBar.appearance()
        navigationBarAppearace.titleTextAttributes = [ NSFontAttributeName: UIFont(name: "Avenir", size: 18)!]
        navigationBarAppearace.titleTextAttributes = [NSForegroundColorAttributeName:UIColor.whiteColor()]
        
        // MARK: checking if user onboarded
        
        let isOnboarded: Bool = NSUserDefaults.standardUserDefaults().boolForKey("Onboarded")
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // instantiate your desired ViewController
        let homeViewController = storyboard.instantiateViewControllerWithIdentifier("HomeViewController") as! UIViewController
        let onboardingViewController = storyboard.instantiateViewControllerWithIdentifier("OnboardingVC") as! UIViewController
        let UserInfoViewController = storyboard.instantiateViewControllerWithIdentifier("namePrompt") as! UIViewController
        
        let window = self.window
        
        if (isOnboarded && PFUser.currentUser()?["name"] == nil) {
            window!.rootViewController = UserInfoViewController
        } else if (isOnboarded) {
            window!.rootViewController = homeViewController
        } else {
            window!.rootViewController = onboardingViewController
        }
        
        // Register for Push Notitications
        if application.applicationState != UIApplicationState.Background {
            // Track an app open here if we launch with a push, unless
            // "content_available" was used to trigger a background push (introduced in iOS 7).
            // In that case, we skip tracking here to avoid double counting the app-open.
            
            let preBackgroundPush = !application.respondsToSelector("backgroundRefreshStatus")
            let oldPushHandlerOnly = !self.respondsToSelector("application:didReceiveRemoteNotification:fetchCompletionHandler:")
            var pushPayload = false
            if let options = launchOptions {
                pushPayload = options[UIApplicationLaunchOptionsRemoteNotificationKey] != nil
            }
            if (preBackgroundPush || oldPushHandlerOnly || pushPayload) {
                PFAnalytics.trackAppOpenedWithLaunchOptions(launchOptions)
            }
        }
        if application.respondsToSelector("registerUserNotificationSettings:") {
            let userNotificationTypes = UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound
            let settings = UIUserNotificationSettings(forTypes: userNotificationTypes, categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        } else {
            let types = UIRemoteNotificationType.Badge | UIRemoteNotificationType.Alert | UIRemoteNotificationType.Sound
            application.registerForRemoteNotificationTypes(types)
        }
        
        if let notificationPayload = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? NSDictionary {
            
            // Create a pointer to the User object
            let userid = notificationPayload["userid"] as? String
            let targetUser = PFObject(withoutDataWithClassName: "_User", objectId: userid)
            
            // Fetch User object
            targetUser.fetchIfNeededInBackgroundWithBlock {
                (object: PFObject?, error:NSError?) -> Void in
                
                if error == nil {
                    // Show TimerViewController
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewControllerWithIdentifier("focusing") as! TimerViewController
                    println("getting called?")
                    
                    // setting target user for view controller / converting PFObject -> PFUser
                    let name = object?.valueForKey("name") as? String ?? "Someone"
                    vc.name = name
                    
                    self.window!.makeKeyAndVisible()
                    self.window!.rootViewController!.presentViewController(vc, animated: true, completion: nil)
                }
            }
        }
        
        let notificationTypes: UIUserNotificationType = UIUserNotificationType.Alert | UIUserNotificationType.Badge | UIUserNotificationType.Sound
        let notificationSettings: UIUserNotificationSettings = UIUserNotificationSettings(forTypes: notificationTypes, categories: nil)
        
        UIApplication.sharedApplication().registerUserNotificationSettings(notificationSettings)
        
        Fabric.with([Digits(), Crashlytics()])
        return true
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        // Store the deviceToken in the current Installation and save it to Parse
        let installation = PFInstallation.currentInstallation()
        installation.setDeviceTokenFromData(deviceToken)
        
        if let user = PFUser.currentUser() {
            installation["user"] = user
        }
        
        installation.saveInBackground()
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        if error.code == 3010 {
            println("Push notifications are not supported in the iOS Simulator.")
        } else {
            println("application:didFailToRegisterForRemoteNotificationsWithError: %@", error)
        }
    }
    
    func application(application: UIApplication,  didReceiveRemoteNotification userInfo: [NSObject : AnyObject],  fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        PFPush.handlePush(userInfo)
        if application.applicationState == UIApplicationState.Inactive {
            PFAnalytics.trackAppOpenedWithRemoteNotificationPayload(userInfo)
        }
        
        println("Current user is \(PFUser.currentUser()) and the token:\(PFUser.currentUser()?.sessionToken)")
        
        if let userid: String = userInfo["userid"] as? String, let punishment = userInfo["punishment"] as? String, let counter = userInfo["counter"] as? Double {
            let targetUser = PFUser(withoutDataWithObjectId: userid)
            targetUser.fetchIfNeededInBackgroundWithBlock { (object: PFObject?, error: NSError?) -> Void in
                
                if error != nil {
                    println(error)
                    println(object?.objectForKey("username") as? String)
                    completionHandler(UIBackgroundFetchResult.Failed)
                } else if PFUser.currentUser() != nil {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = storyboard.instantiateViewControllerWithIdentifier("focusing") as! TimerViewController
                    println("am i getting called?")
                    
                    // setting target user for view controller / converting PFObject -> PFUser
                    //  vc.targetUser = object as? PFUser
                    vc.name = targetUser["name"] as? String
                    //  vc.person
                    vc.punishment = punishment
                    vc.timerDuration = counter
                    
                    self.window!.rootViewController = vc
                    println("second option")

                    completionHandler(UIBackgroundFetchResult.NewData)
                } else {
                    completionHandler(UIBackgroundFetchResult.NoData)
                }
            }
        }
        completionHandler(UIBackgroundFetchResult.NoData)
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        
        println("Backgrounding because of lock button? \(ScreenLockObserver.sharedObserver().didEnterBackgroundDueToLockButtonPress())")
        var startTimer = NSDate()
            
        NSNotificationCenter.defaultCenter().postNotificationName("didEnterBackground", object: nil)

        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        ScreenLockObserver.sharedObserver().applicationWillEnterForeground()
        println("applicatoinWillEnterForeground")

        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NSNotificationCenter.defaultCenter().postNotificationName("didBecomeActive", object: nil)
    }
    
    
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
}