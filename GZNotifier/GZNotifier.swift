//
//  GZNotifier.swift
//  Flingy
//
//  Created by Grady Zhuo on 11/9/14.
//  Copyright (c) 2014 Grady Zhuo. All rights reserved.
//

import UIKit

typealias GZNotifierType = GZNotifier.NotificationType
typealias GZNotifierTemplateView = GZNotifier.TemplateView

typealias GZNotifierAutoHiddenSetting = GZNotifier.AutoHiddenSetting


let GZNotifierShowSuccessNotificationName = "GZNotifierShowSuccessNotificationName"
let GZNotifierShowWarningNotificationName = "GZNotifierShowWarningNotificationName"
let GZNotifierShowFailedNotificationName = "GZNotifierShowFailedNotificationName"

let kGZNotifierShowNotificationMessage = "kGZNotifierShowNotificationMessageKey"
let kGZNotifierShowNotificationTitle = "kGZNotifierShowNotificationTitleKey"
let kGZNotifierShowNotificationAPSUserInfo = "kGZNotifierShowNotificationAPSUserInfo"

let kGZNotifierDefaultShowAnimationDuration = 1.0

@objc protocol GZNotification:NSObjectProtocol {
    
    var message:String { set get }
    
    optional var title:String { set get }
    optional var iconImage:UIImage { set get }
    
    
}

protocol GZNotifierDelegate {
    
//    func notifierShouldAutoHiddenBySetting(notifier:GZNotifier, type:GZNotifierType, notification:GZNotification) -> GZNotifierAutoHiddenSetting
    
    func notifierWillAppear(notifier:GZNotifier, notificationView:GZNotifier.TemplateView)
    func notifierPrepareNotificationView(notifier:GZNotifier, type:GZNotifierType, notification:GZNotification, notificationView:GZNotifierTemplateView)
}

let GZNotifierDefaultContentOffset = CGPoint(x: 0, y: UIApplication.sharedApplication().statusBarFrame.height)
let GZNotifierDefaultContentSize = CGSize(width: UIScreen.mainScreen().bounds.width, height: 60)


struct GZNotifierContentAppearSetting{
    var appearInSize:CGSize
    var appearByOffset:CGPoint
    var autoHiddenSetting:GZNotifierAutoHiddenSetting
}

class GZNotifier{
    
    class var defaultNotifier:GZNotifier {
        
        dispatch_once(&ObjectInfo.singletonOncePtr, { () -> Void in
            ObjectInfo.singleton = GZNotifier()
        })
        
        return ObjectInfo.singleton!
    }
    
    private var templateViewsDict:[NotificationType:Template] = [:]
    private var privateObjectInfo = ObjectInfo()
    
    var delegate:GZNotifierDelegate?
    var animation:GZNotificationAnimation = GZNotificationAnimation()
    
//    var contentOffset:CGPoint
//    var contentSize:CGSize
    
    var contentAppearSetting:GZNotifierContentAppearSetting
    
    var baseView:UIView!{
        set{
            self.privateObjectInfo.shownInView = newValue
        }
        
        get{
            var shownInView:UIView! = self.privateObjectInfo.shownInView
            
            if nil == shownInView{
                if let window = UIApplication.sharedApplication().keyWindow {
                    shownInView = window
                }else{
                    
                    println("Can't find Key window")
                    var customWindow = UIWindow(frame: UIScreen.mainScreen().bounds)
                    customWindow.makeKeyAndVisible()
                    customWindow.windowLevel = UIWindowLevelNormal
                    
                    shownInView = customWindow
                    
                }
            }
            
            return shownInView
        }
        
    
    }
    
    
    // MARK: - Initializer
    init(){
        
        self.contentAppearSetting = GZNotifierContentAppearSetting(appearInSize: GZNotifierDefaultContentSize, appearByOffset: GZNotifierDefaultContentOffset, autoHiddenSetting: GZNotifierAutoHiddenSetting.AutoHiddenAfter(kGZNotifierDefaultShowAnimationDuration))
        
        self.initialize()
        
        
    }
    
    init(contentSize:CGSize, contentOffset:CGPoint, autoHiddenSetting:GZNotifierAutoHiddenSetting){
        
        self.contentAppearSetting = GZNotifierContentAppearSetting(appearInSize: contentSize, appearByOffset: contentOffset, autoHiddenSetting: autoHiddenSetting)
        
        self.initialize()
    }
    
    private func initialize(){
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showByNote:", name: GZNotifierShowSuccessNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showByNote:", name: GZNotifierShowWarningNotificationName, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "showByNote:", name: GZNotifierShowFailedNotificationName, object: nil)
        
        self.register(template: GZNotificationDefaultNormalTemplateView.self, forType: .Normal)
        self.register(template: GZNotificationDefaultSuccessTemplateView.self, forType: .Success)
        self.register(template: GZNotificationDefaultAlertTemplateView.self, forType: .Alert)
        self.register(template: GZNotificationDefaultFailedTemplateView.self, forType: .Failed)
        self.register(template: GZNotificationDefaultWarningTemplateView.self, forType: .Warning)
        
        
        
    }
    
    
    // MARK: - Register Customize Notification View
    
    func register(template templateClass:TemplateView.Type, forType type:NotificationType){
        self.templateViewsDict[type] = Template.FromClass(templateClass)
        
    }
    
    /** Default - Use first-view in instances from the Xib by assigned name and assigned bundle. */
    func register(#nibName:String, inBundle bundle:NSBundle?, forType type:NotificationType){
        
        var nib = UINib(nibName: nibName, bundle: bundle)
        self.register(nib:nib , forType: type)
        
    }
    
    func register(#nibName:String, inBundle bundle:NSBundle?, useIndex viewIndex:Int, forType type:NotificationType){
        
        var nib = UINib(nibName: nibName, bundle: bundle)
        self.register(nib: nib, useIndex: viewIndex, forType: type)
        
    }
    /** Default - Use First View in instants of Xib */
    func register(#nib:UINib, forType type:NotificationType){
        self.register(nib: nib, useIndex: 0, forType: type)
    }
    
    func register(#nib:UINib, useIndex viewIndex:Int, forType type:NotificationType){
        self.templateViewsDict[type] = Template.FromNib(nib, viewIndex)
    }
    
    // MARK: - Show Notification View Operator
    
    func showByNote(note:NSNotification){
        
        var type:GZNotifierType = .Success
        
        switch note.name {
        case GZNotifierShowSuccessNotificationName:
            type = .Success
        case GZNotifierShowWarningNotificationName:
            type = .Warning
        case GZNotifierShowFailedNotificationName:
            type = .Failed
        default:
            type = .Success
        }
        
        var message = ""
        var title:String! = nil
        
        if let userInfo = note.userInfo {
            
            if let messageObject: AnyObject = userInfo[kGZNotifierShowNotificationMessage] {
                message = messageObject as String
            }
            
            if let titleObject:AnyObject = userInfo[kGZNotifierShowNotificationTitle] {
                title = titleObject as String
            }
            
            
        }
        
        if title == nil {
            self.show(type: type, sampleMessage: message, animated: true)
        }else{
            self.show(type: type, sampleMessage: message, sampleTitle: title, animated: true)
        }
        
        
        
    }
    
    
    
    func show(#type:NotificationType, sampleMessage message:String, animated:Bool){
        
        self.show(inView: self.baseView, type: type, sampleMessage: message, animated: animated)

    }
    
    func show(#inView:UIView, type:NotificationType, sampleMessage message:String, animated:Bool){
        
        self.show(inView: inView , type: type, sampleMessage: message, sampleTitle: "", animated: animated)
        
    }
    
    func show(#type:NotificationType, sampleMessage message:String, sampleTitle title:String, animated:Bool){
        
        self.show(inView: self.baseView, type: type, sampleMessage: message, sampleTitle: title, animated: animated)
        
    }
    
    
    func show(#inView:UIView, type:NotificationType, sampleMessage message:String, sampleTitle title:String, animated:Bool){
        
        var notification = type.simpleNotification()
        
        notification.title = title
        notification.message = message
        
        self.show(inView: inView , type: type, notification: notification, animated: animated)
        
    }
    
    func show(#type:NotificationType, notification:GZNotification, animated:Bool){

        self.show(inView: self.baseView, type: type, notification: notification, animated: animated)
        
    }
    
    
    func show(#inView:UIView, type:NotificationType, notification:GZNotification, animated:Bool){
        self.show(inView: inView, type: type, notification: notification, appearSetting: nil, animated: animated)
    }
    
    
    func show(#inView:UIView, type:NotificationType, notification:GZNotification, appearSetting:GZNotifierContentAppearSetting?, animated:Bool){
        
        self.animation.notifier = self
        
        if let template = self.templateViewsDict[type]{
            
            var notificationView = template.createNotificationView()
            notificationView.notification = notification
            notificationView.notifier = self
            
            notificationView.privateObjectInfo.appearInSize = appearSetting?.appearInSize
            notificationView.privateObjectInfo.appearByOffset = appearSetting?.appearByOffset
            
            self.delegate?.notifierPrepareNotificationView(self, type: type, notification: notification, notificationView: notificationView)
            
            var runwayView = GZNotifier.RunWayView()
            
            var runwayFrame = CGRect(origin: notificationView.appearByOffset, size: notificationView.appearInSize)
            var notificationFrame = CGRect(origin: CGPoint(x: 0, y: 0), size: notificationView.appearInSize)
            
            //如果y設為 0，為避開status bar 的處理
            if notificationView.appearByOffset.y == 0 {
                
                var statusFrame = UIApplication.sharedApplication().statusBarFrame
                
                runwayFrame.size.height += statusFrame.height
                
                //notification的高度不變，但y向下移到status之下
                notificationFrame.origin.y = 0//statusFrame.maxY
                notificationFrame.size.height = runwayFrame.size.height
            }
            
            //run way view 增加 status 的 height
            runwayView.frame = runwayFrame
            
            inView.addSubview(runwayView)

            notificationView.frame = notificationFrame
//            notificationView.frame.offset(dx: notificationView.appearByOffset.x, dy: notificationView.appearByOffset.y)
            
            runwayView.addSubview(notificationView)
            
            var autoHiddenSetting = appearSetting?.autoHiddenSetting ?? self.contentAppearSetting.autoHiddenSetting
            
            if let delegate = self.delegate {
                delegate.notifierWillAppear(self, notificationView: notificationView)
            }
            
            switch autoHiddenSetting {
                
            case .Manual:
                println("Manual")
                
            case let .AutoHiddenAfter(hideByAfterTimeInterval):
                self.animation.show(hideAfterDuration: hideByAfterTimeInterval, notificationView: notificationView, completionHandler: { (finished) -> Void in
                    runwayView.removeFromSuperview()
                })
                
            case let .AutoHiddenWhenCompletion(block):
                println("block:\(block)")
            
            }
            
            
            
        }
    }
    
    //MARK: - show in view controller
    
    func show(inViewController viewController:UIViewController, type:NotificationType, sampleMessage message:String, animated:Bool){
        
        var currentAppearSetting = self.contentAppearSetting
        self.contentAppearSetting.appearByOffset.y = viewController.topLayoutGuide.length
        self.show(inView: viewController.view , type: type, sampleMessage: message, sampleTitle: "", animated: animated)
        self.contentAppearSetting = currentAppearSetting
    }
    
    func show(inViewController viewController:UIViewController, type:NotificationType, sampleMessage message:String, sampleTitle title:String, animated:Bool){
        
        var currentAppearSetting = self.contentAppearSetting
        self.contentAppearSetting.appearByOffset.y = viewController.topLayoutGuide.length
        self.show(inView: viewController.view , type: type, sampleMessage: message, sampleTitle: title, animated: animated)
        self.contentAppearSetting = currentAppearSetting
        
    }
    
}


// MARK: - Notifier's private data cache
extension GZNotifier {
    
    private struct ObjectInfo{
        var shownInView:UIView? = nil
        static var singleton:GZNotifier? = nil
        static var singletonOncePtr:dispatch_once_t = 0
    }
    
}


//MARK: - RunwayView

extension GZNotifier{
    class RunWayView:UIView{
        override func layoutSubviews() {
            super.layoutSubviews()
            
            self.clipsToBounds = true
            
        }
    }
}

// MARK: - Enumerator -> NotificationType , AutoHiddeneSetting, Template

extension GZNotifier {
    
    enum NotificationType:String{
        case Undefined = "UNDEFINED"
        
        case Normal = "NORMAL"
        case Success = "SUCCESS"
        case Alert = "ALERT"
        case Failed = "FAILED"
        case Warning = "WARNING"
        
        
        func getNotificationName()->String{
            
            switch self{
                
            case .Warning:
                return GZNotifierShowWarningNotificationName
            case .Failed:
                return GZNotifierShowFailedNotificationName
            default:
                return GZNotifierShowSuccessNotificationName
                
            }
            
            
        }
        
        
    }
    
    enum AutoHiddenSetting{
        case Manual
        case AutoHiddenAfter(NSTimeInterval)
        case AutoHiddenWhenCompletion(()->Void)
    }
    
    private enum Template{
        
        case FromNib(UINib, Int)
        case FromClass(GZNotifier.TemplateView.Type)
        
    }
    
    

    
}

// MARK: - Extensions of NotificationType

extension GZNotifier.NotificationType:Printable{
    
    var description:String {
        return self.rawValue
    }
    
}


private extension GZNotifier.NotificationType{
    
    var test:String{
        return "string"
    }
    
}

// MARK: - Extensions of Template

extension GZNotifier.Template : Printable
{
    var description:String{
        switch self {
            
        case let .FromNib(Nib):
            return "From Nib :\(Nib)"
            
        case let .FromClass(TemplateClass):
            
            var className = String(CString: class_getName(TemplateClass), encoding: NSUTF8StringEncoding)
            return "From Class :\(className)"
        }
        
    }
    
    func createNotificationView()->GZNotifier.TemplateView{
        
        switch self {
            
        case let .FromClass(Class):
            var notificationView = Class()
            return notificationView
            
        case let .FromNib(Nib, ViewIndex):
            var instantsInXib = Nib.instantiateWithOwner(nil, options: nil)
            
            var notificationView = instantsInXib[ViewIndex] as GZNotifier.TemplateView
            
            return notificationView
        }

    }

}


// MARK: - Template View

extension GZNotifier {
    
    class TemplateView:UIView {
        
        private var fromNib:Bool = false
        private var privateObjectInfo = __Cache()
        private var notifier:GZNotifier{
            set{
                self.privateObjectInfo.notifier = newValue
            }
            
            get{
                return self.privateObjectInfo.notifier ?? GZNotifier.defaultNotifier
            }
        }
        
//        private var shouldTranslator:CGPoint{
//            return CGPoint(x: 0, y: -self.frame.maxY)
//        }
        
        var notification:protocol<GZNotification>?
        
        var type:NotificationType{
            return privateObjectInfo.type
        }
        
        required override init() {
            super.init()
            
            self.__initialize()
            
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.__initialize()
            
        }

        required init(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            
            self.__initialize()
            
        }
        
        var appearInSize:CGSize{
            
//            set{
//                self.privateObjectInfo.appearInSize = newValue
//            }
//            
            get{
                
                return self.privateObjectInfo.appearInSize ?? self.notifier.contentAppearSetting.appearInSize
                
            }
            
            
        }
        
        var appearByOffset:CGPoint{
//            set{
//                self.privateObjectInfo.appearByOffset = newValue
//            }
            
            get{
                return self.privateObjectInfo.appearByOffset ?? self.notifier.contentAppearSetting.appearByOffset
            }
        }
        
        
        
        
        private func __initialize(){ /* default do nothing. */ }
        
        private struct __Cache {
            var type:NotificationType = .Undefined
            
            var appearInSize:CGSize? = nil
            var appearByOffset:CGPoint? = nil
            var notifier:GZNotifier? = nil
            
        }
        
        
        deinit{
            println("TemplateView Did Deinit")
        }
        
    }
    
}

// MARK: - Default Template Views

private typealias GZNotificationDefaultTemplateView = GZNotifier.TemplateView.__DefaultTemplateView
private typealias GZNotificationDefaultSuccessTemplateView = GZNotifier.TemplateView.__DefaultTemplateView.__SuccessTemplateView
private typealias GZNotificationDefaultFailedTemplateView = GZNotifier.TemplateView.__DefaultTemplateView.__FailedTemplateView
private typealias GZNotificationDefaultWarningTemplateView = GZNotifier.TemplateView.__DefaultTemplateView.__WarningTemplateView
private typealias GZNotificationDefaultNormalTemplateView = GZNotifier.TemplateView.__DefaultTemplateView.__NormalTemplateView
private typealias GZNotificationDefaultAlertTemplateView = GZNotifier.TemplateView.__DefaultTemplateView.__AlertTemplateView


extension GZNotifier.TemplateView{
    
    private class __DefaultTemplateView: GZNotifier.TemplateView {
        
        
        override var notification:protocol<GZNotification>?{
            didSet{
                
                if let notification = notification{
                    self.messageLabel.text = notification.message
                    
                    if let iconImage = notification.iconImage {
                        self.iconImageView.image = iconImage
                    }
                    
                }
                
            }
        }
        
        var messageLabel:UILabel = UILabel()
        var iconImageView:UIImageView = UIImageView()
        
        override func __initialize() {
            
            super.__initialize()

            self.messageLabel.numberOfLines = 0
            self.messageLabel.textColor = GZNotificationDefaultTemplateView.stokeColor
            
            
            
            self.addSubview(self.messageLabel)
            self.addSubview(self.iconImageView)
            
            
            
            
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            var vaildBounds = self.bounds
            
            if self.appearByOffset.y == 0{
                
                vaildBounds.origin.y += UIApplication.sharedApplication().statusBarFrame.maxY
                vaildBounds.size.height -= UIApplication.sharedApplication().statusBarFrame.maxY
                
            }
            
            
            var imageSize:CGFloat = vaildBounds.height * (44.0/60.0)
            var iconImageSize = CGSize(width: imageSize, height: imageSize)
            
            self.iconImageView.frame.size = iconImageSize
            self.iconImageView.contentMode = UIViewContentMode.ScaleAspectFill
            
            
            self.iconImageView.center = CGPoint(x: iconImageSize.width/2.0, y: vaildBounds.midY)
            self.iconImageView.frame.offset(dx: 6, dy: 0)
            
            
            self.messageLabel.frame.size = CGSize(width: vaildBounds.width - imageSize - 10, height: vaildBounds.height)
            self.messageLabel.frame.origin = CGPoint(x: self.iconImageView.frame.maxX + 5, y: vaildBounds.minY)
            
            self.messageLabel.autoresizingMask = UIViewAutoresizing.FlexibleTopMargin | UIViewAutoresizing.FlexibleLeftMargin
            self.iconImageView.autoresizingMask = UIViewAutoresizing.FlexibleTopMargin | UIViewAutoresizing.FlexibleRightMargin
            
        }
        
    }
    
    
}

extension GZNotifier.TemplateView.__DefaultTemplateView {
    
    class __SuccessTemplateView : __DefaultTemplateView {
        
        private override func __initialize() {
            super.__initialize()
            
            self.backgroundColor = GZNotificationDefaultTemplateView.successColor
        }
        
    }
    
    class __FailedTemplateView : __DefaultTemplateView {
        private override func __initialize() {
            super.__initialize()
            
            self.backgroundColor = GZNotificationDefaultTemplateView.failedColor
        }
        
        
        
    }
    
    class __WarningTemplateView : __DefaultTemplateView {
        
        private override func __initialize() {
            super.__initialize()
            
            self.backgroundColor = GZNotificationDefaultTemplateView.warningColor
            
        }
        
        
        
        
    }
    
    
    
    
    class __NormalTemplateView : __SuccessTemplateView {
        
    }
    
    class __AlertTemplateView : __SuccessTemplateView {
        
    }
    
}

//MARK: - GZNotificationAnimation

class GZNotificationAnimation{
    
    private var privateObjectInfo:ObjectInfo = ObjectInfo()
    
    private var notifier:GZNotifier{
        set{
            self.privateObjectInfo.notifier = newValue
        }
        
        get{
            return self.privateObjectInfo.notifier ?? GZNotifier.defaultNotifier
        }
    }
    
    
//    func show(#hideAfterDuration:NSTimeInterval, notificationView:GZNotifier.TemplateView, willHiddenHandler:()->Void, completionHandler:(finished:Bool)->Void){
//        self.show(notificationView, delay:0, completionHandler: { (finished) -> Void in
//            
//            dispatch_after(<#when: dispatch_time_t#>, <#queue: dispatch_queue_t!#>, <#block: dispatch_block_t!##() -> Void#>)
//            
//            self.hide(notificationView, delay: hideAfterDuration, completionHandler: { (finished) -> Void in
//                completionHandler(finished: finished)
//            })
//            
//        })
//    }
    
    func show(#hideAfterDuration:NSTimeInterval, notificationView:GZNotifier.TemplateView, completionHandler:(finished:Bool)->Void){
        self.show(notificationView, delay:0, completionHandler: { (finished) -> Void in
            self.hide(notificationView, delay: hideAfterDuration, completionHandler: { (finished) -> Void in
                completionHandler(finished: finished)
            })
        })
    }
    
    func show(notificationView:GZNotifier.TemplateView, delay:NSTimeInterval, completionHandler:(finished:Bool)->Void){

        var shouldTranslator = CGPoint(x: 0, y: -notificationView.frame.maxY)
        var startTranslation = CGAffineTransformMakeTranslation(shouldTranslator.x, shouldTranslator.y)
        
        notificationView.transform = startTranslation
        
        UIView.animateWithDuration(0.6, delay: delay, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            
            notificationView.transform = CGAffineTransformIdentity
            
            }) { (finished:Bool) -> Void in
                completionHandler(finished: finished)
        }
        

    }
    
    func hide(notificationView:GZNotifier.TemplateView, delay:NSTimeInterval,completionHandler:(finished:Bool)->Void){
        
        
        var shouldTranslator = CGPoint(x: 0, y: -notificationView.frame.maxY)
        var startTranslation = CGAffineTransformMakeTranslation(shouldTranslator.x, shouldTranslator.y)
        
        UIView.animateWithDuration(0.6, delay: delay, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            notificationView.transform = startTranslation
            }, completion: { (finished:Bool) -> Void in
                completionHandler(finished: finished)
        })
    }
    
    private struct ObjectInfo {
        var notifier:GZNotifier? = nil
    }
    
}


// MARK: - Simple Notification

extension GZNotifierType {
    
    func simpleNotification() -> GZSimpleNotification{
        
        var notification:GZSimpleNotification!
        
        switch self {
        case .Normal:
            fallthrough
        case .Alert:
            fallthrough
        case .Success:
            notification = GZSuccessNotification()
        case .Warning:
            notification = GZWarningNotification()
        case .Failed:
            notification = GZFailNotification()
        default:
            notification = GZSimpleNotification()
        }
        return notification
    }
    
    
    
}

class GZSimpleNotification:NSObject, GZNotification{
    var title:String = "Success!"
    var message:String = ""
    
    
    
}

class GZSuccessNotification:GZSimpleNotification{
    
    // MAKR: - PaintCode Generate

    lazy var iconImage:UIImage = {
    
        var iconSize = CGSize(width: 44, height: 44)
        
        UIGraphicsBeginImageContextWithOptions(iconSize, false, UIScreen.mainScreen().scale)
        GZNotificationDefaultTemplateView.drawNekerSuccessIconImage(CGRect(origin: CGPointZero, size: iconSize), strokeColor: GZNotificationDefaultTemplateView.stokeColor)
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }()
    
    override init() {
        super.init()
        
        self.title = "Success!"
    }
    
}

class GZWarningNotification:GZSimpleNotification{
    
    // MAKR: - PaintCode Generate
    lazy var iconImage:UIImage = {
        
        var iconSize = CGSize(width: 44, height: 44)
        
        UIGraphicsBeginImageContextWithOptions(iconSize, false, UIScreen.mainScreen().scale)
        
        GZNotificationDefaultTemplateView.drawNekerWarningIconImage(CGRect(origin: CGPointZero, size: iconSize), strokeColor: GZNotificationDefaultTemplateView.stokeColor)
        
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }()
    
    override init() {
        super.init()
        
        self.title = "Warning!"
    }
}

class GZFailNotification:GZSimpleNotification{
    
    // MAKR: - PaintCode Generate
    lazy var iconImage:UIImage = {
        
        var iconSize = CGSize(width: 44, height: 44)
        
        UIGraphicsBeginImageContextWithOptions(iconSize, false, UIScreen.mainScreen().scale)
        
        GZNotificationDefaultTemplateView.drawNekerFailedIcon(CGRect(origin: CGPointZero, size: iconSize), strokeColor: GZNotificationDefaultTemplateView.stokeColor)
        
        var image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }()

    
    override init() {
        super.init()
        
        self.title = "Failed!"
    }
}


extension GZNotifier.TemplateView.__DefaultTemplateView {
    
    class var stokeColor:UIColor{
        return ObjectInfo.stokeColor
    }
    
    class var successColor:UIColor{
        return ObjectInfo.successColor
    }
    
    class var failedColor:UIColor{
        return ObjectInfo.failedColor
    }
    
    class var warningColor:UIColor{
        return ObjectInfo.warningColor
    }
    
    private class func drawNekerFailedIcon(frame: CGRect, strokeColor: UIColor) {
        
        //// Bezier 3 Drawing
        var bezier3Path = UIBezierPath()
        bezier3Path.moveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 1.00000 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.22266 * frame.width, frame.minY + 1.00000 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.77734 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.00000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.22266 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.22266 * frame.width, frame.minY + 0.00000 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.77734 * frame.width, frame.minY + 0.00000 * frame.height), controlPoint2: CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.22266 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 1.00000 * frame.height), controlPoint1: CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.77734 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.77734 * frame.width, frame.minY + 1.00000 * frame.height))
        bezier3Path.closePath()
        bezier3Path.moveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.01953 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.23438 * frame.width, frame.minY + 0.01953 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.23438 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.98047 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.76562 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.23438 * frame.width, frame.minY + 0.98047 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.76562 * frame.width, frame.minY + 0.98047 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.76562 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.01953 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.23438 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.76562 * frame.width, frame.minY + 0.01953 * frame.height))
        bezier3Path.closePath()
        bezier3Path.moveToPoint(CGPointMake(frame.minX + 0.69164 * frame.width, frame.minY + 0.26926 * frame.height))
        bezier3Path.addLineToPoint(CGPointMake(frame.minX + 0.73077 * frame.width, frame.minY + 0.30839 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.53017 * frame.width, frame.minY + 0.50900 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.73077 * frame.width, frame.minY + 0.30839 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.63212 * frame.width, frame.minY + 0.40704 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.73199 * frame.width, frame.minY + 0.71082 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.63255 * frame.width, frame.minY + 0.61138 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.73199 * frame.width, frame.minY + 0.71082 * frame.height))
        bezier3Path.addLineToPoint(CGPointMake(frame.minX + 0.69282 * frame.width, frame.minY + 0.74998 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.49100 * frame.width, frame.minY + 0.54816 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.69282 * frame.width, frame.minY + 0.74998 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.59339 * frame.width, frame.minY + 0.65054 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.30839 * frame.width, frame.minY + 0.73077 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.39575 * frame.width, frame.minY + 0.64341 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.30839 * frame.width, frame.minY + 0.73077 * frame.height))
        bezier3Path.addLineToPoint(CGPointMake(frame.minX + 0.26923 * frame.width, frame.minY + 0.69161 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.45184 * frame.width, frame.minY + 0.50900 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.26923 * frame.width, frame.minY + 0.69161 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.35659 * frame.width, frame.minY + 0.60425 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.27045 * frame.width, frame.minY + 0.32760 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.35706 * frame.width, frame.minY + 0.41421 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.27045 * frame.width, frame.minY + 0.32760 * frame.height))
        bezier3Path.addLineToPoint(CGPointMake(frame.minX + 0.30961 * frame.width, frame.minY + 0.28844 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.49100 * frame.width, frame.minY + 0.46983 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.30961 * frame.width, frame.minY + 0.28844 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.39622 * frame.width, frame.minY + 0.37505 * frame.height))
        bezier3Path.addCurveToPoint(CGPointMake(frame.minX + 0.69164 * frame.width, frame.minY + 0.26926 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.59296 * frame.width, frame.minY + 0.36788 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.69164 * frame.width, frame.minY + 0.26926 * frame.height))
        bezier3Path.closePath()
        strokeColor.setFill()
        bezier3Path.fill()
    }

    private class func drawNekerSuccessIconImage(frame: CGRect, strokeColor: UIColor) {
        
        //// Bezier Drawing
        var bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 1.00000 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.22266 * frame.width, frame.minY + 1.00000 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.77734 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.00000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.22266 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.22266 * frame.width, frame.minY + 0.00000 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.77734 * frame.width, frame.minY + 0.00000 * frame.height), controlPoint2: CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.22266 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 1.00000 * frame.height), controlPoint1: CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.77734 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.77734 * frame.width, frame.minY + 1.00000 * frame.height))
        bezierPath.closePath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.01953 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.23437 * frame.width, frame.minY + 0.01953 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.23438 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.98047 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.76562 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.23437 * frame.width, frame.minY + 0.98047 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.76562 * frame.width, frame.minY + 0.98047 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.76562 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.01953 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.23438 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.76562 * frame.width, frame.minY + 0.01953 * frame.height))
        bezierPath.closePath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.43846 * frame.width, frame.minY + 0.65385 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.26923 * frame.width, frame.minY + 0.49642 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.30769 * frame.width, frame.minY + 0.46422 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.43846 * frame.width, frame.minY + 0.58587 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.69615 * frame.width, frame.minY + 0.34615 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.73077 * frame.width, frame.minY + 0.38193 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.43846 * frame.width, frame.minY + 0.65385 * frame.height))
        bezierPath.closePath()
        strokeColor.setFill()
        bezierPath.fill()
    }


    private class func drawNekerWarningIconImage(frame: CGRect, strokeColor: UIColor) {
        
        //// Bezier Drawing
        var bezierPath = UIBezierPath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 1.00000 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.22266 * frame.width, frame.minY + 1.00000 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.77734 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.00000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.00000 * frame.width, frame.minY + 0.22266 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.22266 * frame.width, frame.minY + 0.00000 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.77734 * frame.width, frame.minY + 0.00000 * frame.height), controlPoint2: CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.22266 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 1.00000 * frame.height), controlPoint1: CGPointMake(frame.minX + 1.00000 * frame.width, frame.minY + 0.77734 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.77734 * frame.width, frame.minY + 1.00000 * frame.height))
        bezierPath.closePath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.01953 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.23438 * frame.width, frame.minY + 0.01953 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.23438 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.98047 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.01953 * frame.width, frame.minY + 0.76562 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.23438 * frame.width, frame.minY + 0.98047 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.50000 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.76562 * frame.width, frame.minY + 0.98047 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.76562 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.50000 * frame.width, frame.minY + 0.01953 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.98047 * frame.width, frame.minY + 0.23438 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.76562 * frame.width, frame.minY + 0.01953 * frame.height))
        bezierPath.closePath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.48846 * frame.width, frame.minY + 0.81923 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.43077 * frame.width, frame.minY + 0.76154 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.45601 * frame.width, frame.minY + 0.81923 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.43077 * frame.width, frame.minY + 0.79399 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.48846 * frame.width, frame.minY + 0.70385 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.43077 * frame.width, frame.minY + 0.72548 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.45601 * frame.width, frame.minY + 0.70385 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.54615 * frame.width, frame.minY + 0.76154 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.52452 * frame.width, frame.minY + 0.70385 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.54615 * frame.width, frame.minY + 0.72909 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.48846 * frame.width, frame.minY + 0.81923 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.54615 * frame.width, frame.minY + 0.79399 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.52091 * frame.width, frame.minY + 0.81923 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.48846 * frame.width, frame.minY + 0.81923 * frame.height))
        bezierPath.closePath()
        bezierPath.moveToPoint(CGPointMake(frame.minX + 0.51785 * frame.width, frame.minY + 0.59478 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.47051 * frame.width, frame.minY + 0.59478 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.50996 * frame.width, frame.minY + 0.62610 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.47840 * frame.width, frame.minY + 0.62610 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.41923 * frame.width, frame.minY + 0.32467 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.45868 * frame.width, frame.minY + 0.55955 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.41923 * frame.width, frame.minY + 0.41862 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.57308 * frame.width, frame.minY + 0.32467 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.41923 * frame.width, frame.minY + 0.20332 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.57308 * frame.width, frame.minY + 0.20332 * frame.height))
        bezierPath.addCurveToPoint(CGPointMake(frame.minX + 0.51785 * frame.width, frame.minY + 0.59478 * frame.height), controlPoint1: CGPointMake(frame.minX + 0.56913 * frame.width, frame.minY + 0.41471 * frame.height), controlPoint2: CGPointMake(frame.minX + 0.52968 * frame.width, frame.minY + 0.55955 * frame.height))
        bezierPath.addLineToPoint(CGPointMake(frame.minX + 0.51785 * frame.width, frame.minY + 0.59478 * frame.height))
        bezierPath.closePath()
        strokeColor.setFill()
        bezierPath.fill()
    }

    
    private struct ObjectInfo {
        static var stokeColor: UIColor = UIColor(red: 0.933, green: 0.965, blue: 0.976, alpha: 1.000)
        static var failedColor: UIColor = UIColor(red: 0.839, green: 0.557, blue: 0.557, alpha: 1.000)
        static var successColor: UIColor = UIColor(red: 0.275, green: 0.690, blue: 0.729, alpha: 1.000)
        static var warningColor: UIColor = UIColor(red: 0.937, green: 0.780, blue: 0.106, alpha: 1.000)
    }
    
}


