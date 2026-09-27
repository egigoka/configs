//
//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  ___COPYRIGHT___
//

import Foundation

// MARK: - View Output (Presenter -> View)
protocol PresenterToView___VARIABLE_ModuleName___Protocol: AnyObject {
}

// MARK: - View Input (View -> Presenter)
protocol ViewToPresenter___VARIABLE_ModuleName___Protocol: AnyObject {
    var view: (any PresenterToView___VARIABLE_ModuleName___Protocol)? { get set }
    var interactor: (any PresenterToInteractor___VARIABLE_ModuleName___Protocol)? { get set }
    var router: (any PresenterToRouter___VARIABLE_ModuleName___Protocol)? { get set }
}

// MARK: - Interactor Input (Presenter -> Interactor)
protocol PresenterToInteractor___VARIABLE_ModuleName___Protocol: AnyObject {
    var presenter: (any InteractorToPresenter___VARIABLE_ModuleName___Protocol)? { get set }
}

// MARK: - Interactor Output (Interactor -> Presenter)
protocol InteractorToPresenter___VARIABLE_ModuleName___Protocol: AnyObject {
}

// MARK: - Router Input (Presenter -> Router)
protocol PresenterToRouter___VARIABLE_ModuleName___Protocol: AnyObject {
}
