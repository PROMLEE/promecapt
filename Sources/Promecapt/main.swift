import AppKit

let application = PromecaptApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(UserDefaults.standard.object(forKey: "showDock") as? Bool == true ? .regular : .accessory)
application.run()
