//
//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  ___COPYRIGHT___
//

import Foundation

final class ___VARIABLE_ModuleName___Presenter: ViewToPresenter___VARIABLE_ModuleName___Protocol {

    // MARK: - Properties
    weak var view: (any PresenterToView___VARIABLE_ModuleName___Protocol)?
    var interactor: (any PresenterToInteractor___VARIABLE_ModuleName___Protocol)?
    var router: (any PresenterToRouter___VARIABLE_ModuleName___Protocol)?
}

extension ___VARIABLE_ModuleName___Presenter: InteractorToPresenter___VARIABLE_ModuleName___Protocol {
}
