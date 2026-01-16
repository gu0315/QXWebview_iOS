//
//  NetworkManagerTests.swift
//  chery_iosTests
//
//  Created by AI Assistant on 2025/01/27.
//

import XCTest
@testable import chery_ios

class NetworkManagerTests: XCTestCase {
    
    var networkManager: NetworkManager!
    
    override func setUpWithError() throws {
        networkManager = NetworkManager.shared
    }
    
    override func tearDownWithError() throws {
        networkManager = nil
    }
    
    func testNetworkManagerSingleton() throws {
        let manager1 = NetworkManager.shared
        let manager2 = NetworkManager.shared
        
        XCTAssertTrue(manager1 === manager2, "NetworkManager应该是单例")
    }
    
    func testInvalidURL() throws {
        let expectation = XCTestExpectation(description: "网络请求完成")
        
        networkManager.get(url: "invalid-url", responseType: String.self) { result in
            switch result {
            case .success:
                XCTFail("应该返回失败")
            case .failure(let error):
                XCTAssertEqual(error.localizedDescription, "无效的URL")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testValidURL() throws {
        let expectation = XCTestExpectation(description: "网络请求完成")
        
        // 使用一个测试URL
        networkManager.get(url: "https://httpbin.org/get", responseType: [String: Any].self) { result in
            switch result {
            case .success(let data):
                XCTAssertNotNil(data)
            case .failure(let error):
                XCTFail("请求应该成功: \(error.localizedDescription)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
