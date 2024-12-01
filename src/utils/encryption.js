import CryptoJS from 'crypto-js';

const DEFAULT_PASSWORD = 'defAult.@.Password.';

export const encryptData = (data, password = DEFAULT_PASSWORD) => {
  try {
    const jsonString = JSON.stringify(data);
    const encrypted = CryptoJS.AES.encrypt(jsonString, password).toString();
    // 使用默认密码时添加特殊标记
    const prefix = password === DEFAULT_PASSWORD ? 'default:' : 'encrypted:';
    return `${prefix}${encrypted}`;
  } catch (error) {
    throw new Error('加密失败');
  }
};

export const decryptData = (encryptedData, password) => {
  try {
    // 检查数据格式
    if (!encryptedData.startsWith('encrypted:') && !encryptedData.startsWith('default:')) {
      throw new Error('不是有效的加密数据');
    }
    
    // 根据前缀决定使用的密码
    const isDefaultEncryption = encryptedData.startsWith('default:');
    const actualPassword = isDefaultEncryption ? DEFAULT_PASSWORD : password;
    
    // 如果不是默认加密但没有提供密码
    if (!isDefaultEncryption && !password) {
      throw new Error('请输入解密密码');
    }
    
    // 移除标记前缀
    const prefixLength = isDefaultEncryption ? 8 : 10;
    const actualEncryptedData = encryptedData.substring(prefixLength);
    
    const decrypted = CryptoJS.AES.decrypt(actualEncryptedData, actualPassword);
    const jsonString = decrypted.toString(CryptoJS.enc.Utf8);
    
    if (!jsonString) {
      throw new Error('解密失败，请检查密码是否正确');
    }
    
    return JSON.parse(jsonString);
  } catch (error) {
    throw error.message === '请输入解密密码' ? error : new Error('解密失败，请检查密码是否正确');
  }
};
