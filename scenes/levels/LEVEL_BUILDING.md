# 關卡製作方式

Godot 的獨立場景（`.tscn`）就是 prefab。建立新關卡時，複製 `main.tscn`，
並用「實例化子場景」組合關卡，不要把可互動物件的節點直接複製進關卡。

可重用元件：

- `environment/level_block.tscn`：地板、平台、牆壁與天花板。在 Inspector 調整
  `size` 與 `block_color`；透明色可用來做隱形邊界。
- `anchor/anchor.tscn`：設定唯一的 `anchor_id`、遞增的 `order_index`，起點只允許
  一個並勾選 `is_start_anchor`。
- `goal/goal.tscn`：每關終點。
- `mechanisms/pressure_plate.tscn` + `mechanisms/door.tscn`：在 Door Inspector
  將 `pressure_plate` 指向同關卡的踏板。
- `objects/pushable_box.tscn`：可推動且會被回溯系統自動記錄的箱子。
- `player/player.tscn`、`echo/echo.tscn` 與 `ui/hud.tscn`：共用遊戲系統元件。

建議維持 `StaticGeometry`、`Mechanisms`、`Objects`、`Anchors` 等容器名稱，
讓場景樹容易閱讀。新增需要回溯的動態物件時，實作 `capture_state()` 與
`restore_state(state)`，並加入 `resettable` 群組。
