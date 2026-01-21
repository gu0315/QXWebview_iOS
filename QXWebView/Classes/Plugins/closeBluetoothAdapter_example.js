/**
 * uni.closeBluetoothAdapter(OBJECT) 使用示例
 * 
 * 功能：关闭蓝牙适配器，清理所有蓝牙相关资源
 * 
 * 调用时机：
 * 1. 应用退出时
 * 2. 不再需要使用蓝牙功能时
 * 3. 重新初始化蓝牙前
 */

// 基本用法
function closeBluetoothAdapter() {
    uni.closeBluetoothAdapter({
        success: function(res) {
            console.log('蓝牙适配器关闭成功:', res);
            // res.code: 0 (成功)
            // res.message: "蓝牙适配器已关闭"
            // res.data: {}
        },
        fail: function(err) {
            console.error('蓝牙适配器关闭失败:', err);
            // err.code: 错误码
            // err.message: 错误描述
        },
        complete: function() {
            console.log('蓝牙适配器关闭操作完成');
        }
    });
}

// 完整的蓝牙生命周期管理示例
class BluetoothManager {
    constructor() {
        this.isInitialized = false;
        this.connectedDevices = [];
    }
    
    // 初始化蓝牙
    async initBluetooth() {
        return new Promise((resolve, reject) => {
            uni.initBle({
                success: (res) => {
                    this.isInitialized = true;
                    console.log('蓝牙初始化成功');
                    resolve(res);
                },
                fail: reject
            });
        });
    }
    
    // 扫描设备
    async startScan() {
        if (!this.isInitialized) {
            throw new Error('蓝牙未初始化');
        }
        
        return new Promise((resolve, reject) => {
            uni.startBluetoothDevicesDiscovery({
                timeout: 10000,
                success: resolve,
                fail: reject
            });
        });
    }
    
    // 连接设备
    async connectDevice(deviceId) {
        return new Promise((resolve, reject) => {
            uni.createBLEConnection({
                deviceId: deviceId,
                success: (res) => {
                    this.connectedDevices.push(deviceId);
                    resolve(res);
                },
                fail: reject
            });
        });
    }
    
    // 断开所有连接并关闭蓝牙适配器
    async cleanup() {
        try {
            // 1. 停止扫描
            uni.stopBluetoothDevicesDiscovery({});
            
            // 2. 断开所有连接
            for (const deviceId of this.connectedDevices) {
                await new Promise((resolve) => {
                    uni.closeBLEConnection({
                        deviceId: deviceId,
                        complete: resolve
                    });
                });
            }
            
            // 3. 关闭蓝牙适配器
            await new Promise((resolve, reject) => {
                uni.closeBluetoothAdapter({
                    success: resolve,
                    fail: reject
                });
            });
            
            // 4. 重置状态
            this.isInitialized = false;
            this.connectedDevices = [];
            
            console.log('蓝牙资源清理完成');
            
        } catch (error) {
            console.error('蓝牙资源清理失败:', error);
        }
    }
}

// 使用示例
const bluetoothManager = new BluetoothManager();

// 页面加载时初始化
async function onPageLoad() {
    try {
        await bluetoothManager.initBluetooth();
        await bluetoothManager.startScan();
    } catch (error) {
        console.error('蓝牙初始化失败:', error);
    }
}

// 页面卸载时清理
async function onPageUnload() {
    await bluetoothManager.cleanup();
}

// 应用退出时清理
function onAppExit() {
    // 同步调用，确保资源被清理
    uni.closeBluetoothAdapter({
        success: function() {
            console.log('应用退出时蓝牙适配器已关闭');
        }
    });
}

// 重新初始化蓝牙前的清理
async function reinitializeBluetooth() {
    // 先关闭现有适配器
    await new Promise((resolve) => {
        uni.closeBluetoothAdapter({
            complete: resolve
        });
    });
    
    // 等待一段时间确保资源完全释放
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // 重新初始化
    await bluetoothManager.initBluetooth();
}

// 导出方法供外部使用
export {
    closeBluetoothAdapter,
    BluetoothManager,
    onPageLoad,
    onPageUnload,
    onAppExit,
    reinitializeBluetooth
};