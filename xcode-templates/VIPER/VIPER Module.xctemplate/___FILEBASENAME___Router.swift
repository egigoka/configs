//
//  ___FILENAME___
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  ___COPYRIGHT___
//

import UIKit

final class ___VARIABLE_ModuleName___Router: PresenterToRouter___VARIABLE_ModuleName___Protocol {

    // MARK: - Static methods
    @MainActor
    static func createModule() -> UIViewController {
        let viewController = ___VARIABLE_ModuleName___ViewController()

        let presenter: any ViewToPresenter___VARIABLE_ModuleName___Protocol & InteractorToPresenter___VARIABLE_ModuleName___Protocol = ___VARIABLE_ModuleName___Presenter()

        viewController.presenter = presenter
        viewController.presenter?.router = ___VARIABLE_ModuleName___Router()
        viewController.presenter?.view = viewController
        viewController.presenter?.interactor = ___VARIABLE_ModuleName___Interactor()
        viewController.presenter?.interactor?.presenter = presenter

        return viewController
    }
}
