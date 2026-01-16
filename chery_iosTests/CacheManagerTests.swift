//
//  CacheManagerTests.swift
//  chery_iosTests
//
//  Created by AI Assistant on 2025/01/27.
//

import XCTest
@testable import chery_ios

class CacheManagerTests: XCTestCase {
    
    var cacheManager: CacheManager!
    
    override func setUpWithError() throws {
        cacheManager = CacheManager.shared
    }
    
    override func tearDownWithError() throws {
        cacheManager.clearAllCache()
    }
    
    func testCacheManagerSingleton() throws {
        let manager1 = CacheManager.shared
        let manager2 = CacheManager.shared
        
        XCTAssertTrue(manager1 === manager2, "CacheManager应该是单例")
    }
    
    func testSetAndGetCache() throws {
        let testData = ["key": "value", "number": 123]
        let key = "testKey"
        
        // 设置缓存
        cacheManager.setCache(testData, forKey: key)
        
        // 获取缓存
        let retrievedData = cacheManager.getCache([String: Any].self, forKey: key)
        
        XCTAssertNotNil(retrievedData)
        XCTAssertEqual(retrievedData?["key"] as? String, "value")
        XCTAssertEqual(retrievedData?["number"] as? Int, 123)
    }
    
    func testCacheExpiration() throws {
        let testData = "testData"
        let key = "expiredKey"
        
        // 设置短期过期的缓存
        cacheManager.setCache(testData, forKey: key, expirationTime: 0.1)
        
        // 立即获取应该成功
        let immediateData = cacheManager.getCache(String.self, forKey: key)
        XCTAssertNotNil(immediateData)
        XCTAssertEqual(immediateData, testData)
        
        // 等待过期
        let expectation = XCTestExpectation(description: "等待缓存过期")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let expiredData = self.cacheManager.getCache(String.self, forKey: key)
            XCTAssertNil(expiredData, "过期的缓存应该返回nil")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testRemoveCache() throws {
        let testData = "testData"
        let key = "removeKey"
        
        // 设置缓存
        cacheManager.setCache(testData, forKey: key)
        
        // 验证缓存存在
        let beforeRemove = cacheManager.getCache(String.self, forKey: key)
        XCTAssertNotNil(beforeRemove)
        
        // 删除缓存
        cacheManager.removeCache(forKey: key)
        
        // 验证缓存已删除
        let afterRemove = cacheManager.getCache(String.self, forKey: key)
        XCTAssertNil(afterRemove)
    }
    
    func testClearAllCache() throws {
        let testData1 = "testData1"
        let testData2 = "testData2"
        let key1 = "key1"
        let key2 = "key2"
        
        // 设置多个缓存
        cacheManager.setCache(testData1, forKey: key1)
        cacheManager.setCache(testData2, forKey: key2)
        
        // 验证缓存存在
        XCTAssertNotNil(cacheManager.getCache(String.self, forKey: key1))
        XCTAssertNotNil(cacheManager.getCache(String.self, forKey: key2))
        
        // 清除所有缓存
        cacheManager.clearAllCache()
        
        // 验证所有缓存已清除
        XCTAssertNil(cacheManager.getCache(String.self, forKey: key1))
        XCTAssertNil(cacheManager.getCache(String.self, forKey: key2))
    }
}
