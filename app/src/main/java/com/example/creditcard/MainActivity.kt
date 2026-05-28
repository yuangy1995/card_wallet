package com.example.creditcard

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import com.example.creditcard.theme.CreditCardTheme
import com.example.creditcard.utils.SyncCoordinator
import com.example.creditcard.utils.ThemeManager

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // 初始化本地主题偏好及数据仓库
    ThemeManager.init(this)
    SyncCoordinator.initLocalData(this)

    enableEdgeToEdge()
    setContent {
      // 监听全局主题状态，动态响应热切换
      val isDark by ThemeManager.isDarkTheme.collectAsState()
      
      CreditCardTheme(darkTheme = isDark) { 
        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) { 
          MainNavigation() 
        } 
      }
    }
  }
}
