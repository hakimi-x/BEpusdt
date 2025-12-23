package web

import (
	"github.com/gin-gonic/gin"
	"github.com/v03413/bepusdt/app/log"
	"github.com/v03413/bepusdt/app/model"
)

// getTradeTypes 获取已配置的链类型列表
func getTradeTypes(c *gin.Context) {
	log.Info("getTradeTypes called")
	
	var types []string
	result := model.DB.Model(&model.WalletAddress{}).
		Distinct("trade_type").
		Where("status = ?", model.StatusEnable).
		Pluck("trade_type", &types)
	
	if result.Error != nil {
		log.Error("getTradeTypes DB error:", result.Error)
	}
	
	log.Info("getTradeTypes result:", types)

	c.JSON(200, gin.H{
		"status_code": 200,
		"message":     "success",
		"data": gin.H{
			"trade_types": types,
		},
	})
}
