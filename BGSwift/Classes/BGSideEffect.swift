//
//  Copyright © 2021 Yahoo
//

import Foundation

struct BGSideEffect {
    let label: String?
    let event: BGEvent
    let run: () -> Void
    
    init(label: String? = nil, event: BGEvent, run: @escaping () -> Void) {
        self.label = label
        self.event = event
        self.run = run
    }
}
