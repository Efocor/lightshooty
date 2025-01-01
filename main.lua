--... @FECORO, 2023...--

--[[ 
* Juego hecho por Felipe Alexander Correa Rodríguez (FECORO)
* Prueba de uso de LUA con LOVE2D

* Controles:
    * W, A, S, D: Movimiento
    * Mouse: Apuntar y disparar
    * Espacio: Dash
    * Shift: Hacerse pequeño
    * Click izquierdo: Disparar
    * Click derecho: Recargar munición
    * R: Reiniciar nivel
    * Esc: Salir del juego

* Objetivo:
    * Llegar a la meta (triángulo verde) para pasar al siguiente nivel
    * Eliminar enemigos para ganar puntos y experiencia
    * Recoger power-ups para recuperar salud, aumentar velocidad de disparo o recargar munición
    * Cuidado con los enemigos, te quitarán salud si te tocan
    * Cada nivel aumenta la dificultad y el tamaño del mapa

* Notas:
Juego básico de disparos top-down con mecánicas simples y efectos visuales.

Por Feri.
]]--


--............................................................| código del juego.
--... configuración inicial
function love.load()
    love.window.setTitle("Top-Down Shooter Enhanced")
    love.window.setMode(1024, 768, {resizable=false})
    math.randomseed(os.time())

    --... nivel
    level = 1

    --... jugador
    player = {
        x = 100,
        y = 100,
        speed = 250,
        normalSpeed = 250,
        dashSpeed = 600,
        radius = 15,
        normalRadius = 15,
        smallRadius = 8,
        color = {0.5, 0.5, 1},
        trail = {},
        auraTimer = 0,
        fireRate = 0.2,
        fireTimer = 0,
        health = 100,
        maxHealth = 100,
        score = 0,
        experience = 0,
        level = 1,
        expToNextLevel = 100,
        canDash = true,
        dashCooldown = 2,
        dashTimer = 0,
        isDashing = false,
        dashDuration = 0.2,
        dashTime = 0,
        isSmall = false,
        ammo = 100,
        maxAmmo = 100,
    }

    --... los enemigos
    enemies = {}
    enemySpawnTimer = 0

    --... balitas
    bullets = {}

    --... power-ups
    powerups = {}
    powerupSpawnTimer = 5

    --... le map
    baseMapSize = 2000
    mapWidth = baseMapSize
    mapHeight = baseMapSize
    updateMapSize()
    walls = generateWalls()

    --... cámara
    camera = {x = 0, y = 0}

    --... meta
    goal = generateGoal()

    --... partículas
    particleSystems = {}

    --... minimapa
    minimapCanvas = love.graphics.newCanvas(200, 200)

    --... se agrega fuentes para la interfaz
    font = love.graphics.newFont(14)
    love.graphics.setFont(font)

    --... sonidos (hay que tenerlos en el directorio)
    sounds = {
        shoot = love.audio.newSource("shoot.wav", "static"),
        explosion = love.audio.newSource("explosion.wav", "static"),
        powerup = love.audio.newSource("powerup.wav", "static"),
    }
end

--... actualización del juego
function love.update(dt)
    --... actualiza al jugador
    updatePlayer(dt)

    --... actualiza balas
    updateBullets(dt)

    --... actualiza enemigos
    updateEnemies(dt)

    --... idem power-ups
    updatePowerUps(dt)

    --... idem partículas
    updateParticles(dt)

    --... colisiones
    checkCollisions()

    --... genera enemigos
    enemySpawnTimer = enemySpawnTimer - dt
    if enemySpawnTimer <= 0 then
        spawnEnemy()
        enemySpawnTimer = math.max(1, 3 - level * 0.1)
    end

    --... genera power-ups
    powerupSpawnTimer = powerupSpawnTimer - dt
    if powerupSpawnTimer <= 0 then
        spawnPowerUp()
        powerupSpawnTimer = math.random(10, 20)
    end

    --... verifica si el jugador llega a la meta
    if pointInTriangle(player.x, player.y, goal.vertices) then
        nextLevel()
    end

    --... actualiza minimapa
    updateMinimap()
end

--... dibujo del juego
function love.draw()
    love.graphics.push()
    love.graphics.translate(-camera.x, -camera.y)

    --... dibujo mapa (fondo)
    love.graphics.clear(0.08, 0.08, 0.1)

    --... dibujo paredes
    love.graphics.setColor(0.6, 0.6, 0.6)
    for _, wall in ipairs(walls) do
        love.graphics.rectangle("fill", wall.x, wall.y, wall.width, wall.height)
    end

    --... dibujo meta (triángulo)
    love.graphics.setColor(0, 1, 0)
    love.graphics.polygon("fill", goal.vertices)

    --... dibujo jugador
    drawPlayer()

    --... dibujo balas
    for _, bullet in ipairs(bullets) do
        love.graphics.setColor(bullet.color)
        love.graphics.circle("fill", bullet.x, bullet.y, bullet.radius)
    end

    --... dibujo enemigos
    for _, enemy in ipairs(enemies) do
        drawEnemy(enemy)
    end

    --... dibujo power-ups
    for _, powerup in ipairs(powerups) do
        love.graphics.setColor(powerup.color)
        love.graphics.rectangle("fill", powerup.x - powerup.size / 2, powerup.y - powerup.size / 2, powerup.size, powerup.size)
    end

    --... dibujo partículas
    for _, ps in ipairs(particleSystems) do
        love.graphics.draw(ps)
    end

    love.graphics.pop()

    --... dibujo la famosa y simplesca interfaz
    drawUI()

    --... dibujar minimapa
    drawMinimap()
end

--... actualizo minimapa
function updateMinimap()
    love.graphics.setCanvas(minimapCanvas)
    love.graphics.clear()

    local scaleX = minimapCanvas:getWidth() / mapWidth
    local scaleY = minimapCanvas:getHeight() / mapHeight

    --... dibuja meta en el minimapa
    love.graphics.setColor(0, 1, 0)
    love.graphics.circle("fill", goal.x * scaleX, goal.y * scaleY, 5)

    --... dibuja jugador en el minimapa
    love.graphics.setColor(0.5, 0.5, 1)
    love.graphics.circle("fill", player.x * scaleX, player.y * scaleY, 5)

    love.graphics.setCanvas()
end

--... dibuja minimapa
function drawMinimap()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(minimapCanvas, love.graphics.getWidth() - minimapCanvas:getWidth() - 10, 10)
    love.graphics.rectangle("line", love.graphics.getWidth() - minimapCanvas:getWidth() - 10, 10, minimapCanvas:getWidth(), minimapCanvas:getHeight())
end

--... funciones de actualización
function updatePlayer(dt)
    --... movimiento del jugador
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length

        local speed = player.speed
        --... aplica velocidad de dash
        if player.isDashing then
            speed = player.dashSpeed
            player.dashTime = player.dashTime + dt
            if player.dashTime >= player.dashDuration then
                player.isDashing = false
                player.dashTime = 0
                player.dashTimer = player.dashCooldown
            end
        end

        player.x = player.x + dx * speed * dt
        player.y = player.y + dy * speed * dt

        --... agrega al rastro
        player.auraTimer = player.auraTimer + dt
        if player.auraTimer > 0.02 then
            table.insert(player.trail, {x = player.x, y = player.y, alpha = 0.5})
            player.auraTimer = 0
        end
    end

    --... maneja cooldown del dash
    if not player.canDash then
        player.dashTimer = player.dashTimer - dt
        if player.dashTimer <= 0 then
            player.canDash = true
        end
    end

    --... acción de dash
    if love.keyboard.isDown("space") and player.canDash and not player.isDashing then
        player.isDashing = true
        player.canDash = false
        playDashEffect()
    end

    --... acción de hacerse pequeño
    if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
        player.isSmall = true
        player.radius = player.smallRadius
        player.speed = player.normalSpeed + 50 --... Más rápido al ser pequeño (pero no tanto como con el dash)
    else
        player.isSmall = false
        player.radius = player.normalRadius
        player.speed = player.normalSpeed
    end

    --... mantener dentro del mapa
    player.x = clamp(player.x, player.radius, mapWidth - player.radius)
    player.y = clamp(player.y, player.radius, mapHeight - player.radius)

    --... actualizo el rastro/estela
    for i = #player.trail, 1, -1 do
        local t = player.trail[i]
        t.alpha = t.alpha - dt * 1
        if t.alpha <= 0 then
            table.remove(player.trail, i)
        end
    end

    --... disparar
    player.fireTimer = player.fireTimer - dt
    if love.mouse.isDown(1) and player.fireTimer <= 0 and player.ammo > 0 then
        shootBullet()
        player.fireTimer = player.fireRate
        player.ammo = player.ammo - 1
    end

    --... colisiones con paredes
    for _, wall in ipairs(walls) do
        if checkCircleRectCollision(player.x, player.y, player.radius, wall) then
            resolveCollision(player, wall)
        end
    end

    --... la camarinha
    camera.x = player.x - love.graphics.getWidth() / 2
    camera.y = player.y - love.graphics.getHeight() / 2

    --... limita cámara al tamaño del mapa
    camera.x = clamp(camera.x, 0, mapWidth - love.graphics.getWidth())
    camera.y = clamp(camera.y, 0, mapHeight - love.graphics.getHeight())

    --... experiencia y subida de nivel
    if player.experience >= player.expToNextLevel then
        player.experience = player.experience - player.expToNextLevel
        player.level = player.level + 1
        player.expToNextLevel = math.floor(player.expToNextLevel * 1.5)
        player.maxHealth = player.maxHealth + 20
        player.health = player.maxHealth
        player.maxAmmo = player.maxAmmo + 20
        player.ammo = player.maxAmmo
        player.normalSpeed = player.normalSpeed + 10
    end
end

function updateBullets(dt)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.dx * b.speed * dt
        b.y = b.y + b.dy * b.speed * dt

        --... aañade partículas a las balas
        addBulletTrail(b)

        --... elimina balas fuera del mapa
        if b.x < 0 or b.x > mapWidth or b.y < 0 or b.y > mapHeight then
            table.remove(bullets, i)
        else
            --... colisión con paredes
            for _, wall in ipairs(walls) do
                if checkCircleRectCollision(b.x, b.y, b.radius, wall) then
                    --... genera efecto de impacto
                    spawnImpactEffect(b.x, b.y)
                    table.remove(bullets, i)
                    break
                end
            end
        end
    end
end

function updateEnemies(dt)
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e.behavior(dt, e)

        --... agregar al rastro
        e.auraTimer = e.auraTimer + dt
        if e.auraTimer > 0.05 then
            table.insert(e.trail, {x = e.x, y = e.y, alpha = 0.5, color = e.color})
            e.auraTimer = 0
        end

        --... actualizar rastro
        for j = #e.trail, 1, -1 do
            local t = e.trail[j]
            t.alpha = t.alpha - dt * 0.5
            if t.alpha <= 0 then
                table.remove(e.trail, j)
            end
        end

        --... colisiones con paredes
        for _, wall in ipairs(walls) do
            if checkCircleRectCollision(e.x, e.y, e.radius, wall) then
                resolveCollision(e, wall)
            end
        end

        --... eliminar enemigos sin salud
        if e.health <= 0 then
            --... efecto visual al eliminar enemigo
            spawnExplosion(e.x, e.y, e.color)
            table.remove(enemies, i)
            player.score = player.score + 10
            player.experience = player.experience + 20
        end
    end
end

function updatePowerUps(dt)
    --... en este ejemplo, los power-ups no tienen lógica de movimiento
end

function updateParticles(dt)
    for i = #particleSystems, 1, -1 do
        local ps = particleSystems[i]
        ps:update(dt)
        if ps:getCount() == 0 and ps:isStopped() then
            table.remove(particleSystems, i)
        end
    end
end

--... funciones de dibujo
function drawPlayer()
    --... dibuja la estela
    for _, t in ipairs(player.trail) do
        love.graphics.setColor(0.5, 0.5, 1, t.alpha)
        love.graphics.circle("fill", t.x, t.y, player.radius)
    end

    --... dibujar aura
    love.graphics.setColor(0.5, 0.5, 1, 0.7)
    love.graphics.circle("fill", player.x, player.y, player.radius + 5)

    --... dibujar jugador
    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.circle("fill", player.x, player.y, player.radius)
end

function drawEnemy(enemy)
    --... dibujar estela
    for _, t in ipairs(enemy.trail) do
        love.graphics.setColor(t.color[1], t.color[2], t.color[3], t.alpha)
        love.graphics.circle("fill", t.x, t.y, enemy.radius)
    end

    --... dibujar aura
    love.graphics.setColor(enemy.color[1], enemy.color[2], enemy.color[3], 0.7)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius + 5)

    --... dibujar enemigo
    love.graphics.setColor(enemy.color)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius)
end

function drawUI()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Salud: " .. math.floor(player.health) .. "/" .. player.maxHealth, 10, 10)
    love.graphics.print("Puntuación: " .. player.score, 10, 30)
    love.graphics.print("Nivel: " .. player.level, 10, 50)
    love.graphics.print("XP: " .. player.experience .. "/" .. player.expToNextLevel, 10, 70)
    love.graphics.print("Munición: " .. player.ammo .. "/" .. player.maxAmmo, 10, 90)
    if not player.canDash then
        love.graphics.print("Dash en: " .. string.format("%.1f", player.dashTimer) .. "s", 10, 110)
    else
        love.graphics.print("Dash listo", 10, 110)
    end
end

--... funciones auxiliares
function shootBullet()
    local mx, my = love.mouse.getPosition()
    mx = mx + camera.x
    my = my + camera.y
    local angle = math.atan(my - player.y, mx - player.x)
    local bullet = {
        x = player.x,
        y = player.y,
        dx = math.cos(angle),
        dy = math.sin(angle),
        speed = 700,
        radius = 5,
        color = {1, 0.5, 0},
        trail = {},
        trailTimer = 0
    }
    table.insert(bullets, bullet)
    sounds.shoot:stop()
    sounds.shoot:play()
end

function addBulletTrail(bullet)
    bullet.trailTimer = bullet.trailTimer + love.timer.getDelta()
    if bullet.trailTimer > 0.01 then
        table.insert(bullet.trail, {x = bullet.x, y = bullet.y, alpha = 0.5})
        bullet.trailTimer = 0
    end

    --... actualiza y dibuja el rastro de la bala
    for i = #bullet.trail, 1, -1 do
        local t = bullet.trail[i]
        t.alpha = t.alpha - love.timer.getDelta() * 2
        if t.alpha <= 0 then
            table.remove(bullet.trail, i)
        else
            love.graphics.setColor(bullet.color[1], bullet.color[2], bullet.color[3], t.alpha)
            love.graphics.circle("fill", t.x, t.y, bullet.radius)
        end
    end
end

function spawnEnemy()
    local enemy = {}
    repeat
        enemy.x = math.random(50, mapWidth - 50)
        enemy.y = math.random(50, mapHeight - 50)
    until distance(enemy.x, enemy.y, player.x, player.y) > 300

    enemy.radius = 15
    local hue = math.random(0, 360)
    enemy.color = hsvToRgb(hue, 1, 1)
    enemy.speed = 100 + (hue / 360) * 50 + level * 5 --... Velocidad basada en el nivel
    enemy.health = 50 + (level * 10)
    enemy.trail = {}
    enemy.auraTimer = 0

    --... asigna tipo y comportamiento
    local enemyTypeRoll = math.random()
    if enemyTypeRoll < 0.4 then
        enemy.type = "chaser"
        enemy.behavior = enemyChaserBehavior
    elseif enemyTypeRoll < 0.7 then
        enemy.type = "shooter"
        enemy.behavior = enemyShooterBehavior
        enemy.shootTimer = math.random(2, 4)
    else
        enemy.type = "splitter"
        enemy.behavior = enemySplitterBehavior
    end

    table.insert(enemies, enemy)
end

function enemyChaserBehavior(dt, self)
    --... movimiento hacia el jugador
    local dx = player.x - self.x
    local dy = player.y - self.y
    local length = math.sqrt(dx * dx + dy * dy)
    dx = dx / length
    dy = dy / length
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
end

function enemyShooterBehavior(dt, self)
    --... Mantener distancia y disparar al jugador
    local dx = player.x - self.x
    local dy = player.y - self.y
    local distanceToPlayer = math.sqrt(dx * dx + dy * dy)
    if distanceToPlayer > 300 then
        --... Acercarse
        dx = dx / distanceToPlayer
        dy = dy / distanceToPlayer
        self.x = self.x + dx * self.speed * dt
        self.y = self.y + dy * self.speed * dt
    elseif distanceToPlayer < 200 then
        --... Alejarse
        dx = dx / distanceToPlayer
        dy = dy / distanceToPlayer
        self.x = self.x - dx * self.speed * dt
        self.y = self.y - dy * self.speed * dt
    end

    --... Disparar
    self.shootTimer = self.shootTimer - dt
    if self.shootTimer <= 0 then
        enemyShoot(self)
        self.shootTimer = math.random(2, 4)
    end
end

function enemySplitterBehavior(dt, self)
    --... movimiento aleatorio
    self.angle = self.angle or math.random() * math.pi * 2
    self.y = self.y + math.sin(self.angle) * self.speed * dt
    self.angle = self.angle + math.random(-1, 1) * dt
end

function enemyShoot(enemy)
    local angle = math.atan(player.y - enemy.y, player.x - enemy.x)
    local bullet = {
        x = enemy.x,
        y = enemy.y,
        dx = math.cos(angle),
        dy = math.sin(angle),
        speed = 500,
        radius = 5,
        color = {1, 0, 1},
        trail = {},
        trailTimer = 0,
        enemyBullet = true
    }
    table.insert(bullets, bullet)
end

function spawnPowerUp()
    local powerup = {}
    powerup.x = math.random(50, mapWidth - 50)
    powerup.y = math.random(50, mapHeight - 50)
    powerup.size = 20
    local powerupTypeRoll = math.random()
    if powerupTypeRoll < 0.4 then
        powerup.type = "health"
        powerup.color = {0, 1, 0}
    elseif powerupTypeRoll < 0.7 then
        powerup.type = "fireRate"
        powerup.color = {0, 0, 1}
    else
        powerup.type = "ammo"
        powerup.color = {1, 1, 0}
    end
    table.insert(powerups, powerup)
end

function checkCollisions()
    --... colisión balas con enemigos
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        local isEnemyBullet = b.enemyBullet

        if not isEnemyBullet then
            for j = #enemies, 1, -1 do
                local e = enemies[j]
                if distance(b.x, b.y, e.x, e.y) < b.radius + e.radius then
                    --... reduce salud del enemigo
                    e.health = e.health - 25
                    --... genera efecto de impacto
                    spawnImpactEffect(b.x, b.y)
                    --... elimina bala
                    table.remove(bullets, i)
                    break
                end
            end
        else
            --... colisión de balas enemigas con el jugador
            if distance(b.x, b.y, player.x, player.y) < b.radius + player.radius then
                --... reduce salud del jugador
                player.health = player.health - 25
                if player.health <= 0 then
                    --... fin del juego
                    love.event.quit()
                end
                --... genera efecto de impacto
                spawnImpactEffect(b.x, b.y)
                --... elimina bala
                table.remove(bullets, i)
            end
        end
    end

    --... colisión jugador con enemigos
    for _, e in ipairs(enemies) do
        if distance(player.x, player.y, e.x, e.y) < player.radius + e.radius then
            --... reduce salud del jugador
            player.health = player.health - 50 * love.timer.getDelta()
            if player.health <= 0 then
                --... fin del juego
                love.event.quit()
            end
        end
    end

    --... colisión jugador con power-ups
    for i = #powerups, 1, -1 do
        local p = powerups[i]
        if distance(player.x, player.y, p.x, p.y) < player.radius + p.size / 2 then
            if p.type == "health" then
                player.health = math.min(player.maxHealth, player.health + 25)
            elseif p.type == "fireRate" then
                player.fireRate = 0.1 --... aumenta velocidad de disparo
                --... se agrega temporizador para restablecer velocidad normal
                player.powerUpTimer = 5
            elseif p.type == "ammo" then
                player.ammo = math.min(player.maxAmmo, player.ammo + 50)
            end
            sounds.powerup:stop()
            sounds.powerup:play()
            table.remove(powerups, i)
        end
    end

    --... maneja temporizador de power-up
    if player.powerUpTimer then
        player.powerUpTimer = player.powerUpTimer - love.timer.getDelta()
        if player.powerUpTimer <= 0 then
            player.fireRate = 0.2 --... restablecemos velocidad normal de disparo
            player.powerUpTimer = nil
        end
    end
end

function nextLevel()
    level = level + 1
    player.x = 100
    player.y = 100
    player.health = player.maxHealth
    player.ammo = player.maxAmmo
    enemies = {}
    bullets = {}
    powerups = {}
    particleSystems = {}
    --... aumenta el tamaño del mapa
    updateMapSize()
    walls = generateWalls()
    --... nueva meta
    goal = generateGoal()
end

function updateMapSize()
    local increment = (level - 1) * 500
    mapWidth = baseMapSize + increment
    mapHeight = baseMapSize + increment
end

function generateGoal()
    local size = 30
    local x = math.random(100, mapWidth - 100)
    local y = math.random(100, mapHeight - 100)
    local vertices = {
        x, y - size,
        x - size, y + size,
        x + size, y + size
    }
    return {x = x, y = y, size = size, vertices = vertices}
end

function generateWalls()
    local walls = {}
    --... genera paredes para crear habitaciones y laberintos
    local numWalls = 20 + level * 5
    for i = 1, numWalls do
        local wall = {}
        wall.x = math.random(0, mapWidth - 200)
        wall.y = math.random(0, mapHeight - 200)
        if math.random() > 0.5 then
            wall.width = math.random(200, 400)
            wall.height = 20
        else
            wall.width = 20
            wall.height = math.random(200, 400)
        end
        table.insert(walls, wall)
    end
    return walls
end

function checkCircleRectCollision(cx, cy, radius, rect)
    local closestX = clamp(cx, rect.x, rect.x + rect.width)
    local closestY = clamp(cy, rect.y, rect.y + rect.height)
    local dx = cx - closestX
    local dy = cy - closestY
    return (dx * dx + dy * dy) < (radius * radius)
end

function resolveCollision(circle, rect)
    local overlapX = 0
    local overlapY = 0

    if circle.x < rect.x then
        overlapX = circle.x - (rect.x - circle.radius)
    elseif circle.x > rect.x + rect.width then
        overlapX = circle.x - (rect.x + rect.width + circle.radius)
    end

    if circle.y < rect.y then
        overlapY = circle.y - (rect.y - circle.radius)
    elseif circle.y > rect.y + rect.height then
        overlapY = circle.y - (rect.y + rect.height + circle.radius)
    end

    if math.abs(overlapX) < math.abs(overlapY) then
        circle.x = circle.x - overlapX
    else
        circle.y = circle.y - overlapY
    end
end

function distance(x1, y1, x2, y2)
    return ((x2 - x1)^2 + (y2 - y1)^2)^(0.5)
end

function clamp(x, minVal, maxVal)
    return math.max(minVal, math.min(maxVal, x))
end

function hsvToRgb(h, s, v)
    h = h % 360
    local c = v * s
    local x = c * (1 - math.abs(((h / 60) % 2) - 1))
    local m = v - c
    local r, g, b = 0, 0, 0

    if h >= 0 and h < 60 then
        r, g, b = c, x, 0
    elseif h >= 60 and h < 120 then
        r, g, b = x, c, 0
    elseif h >= 120 and h < 180 then
        r, g, b = 0, c, x
    elseif h >= 180 and h < 240 then
        r, g, b = 0, x, c
    elseif h >= 240 and h < 300 then
        r, g, b = x, 0, c
    elseif h >= 300 and h < 360 then
        r, g, b = c, 0, x
    end

    return {r + m, g + m, b + m}
end

function pointInTriangle(px, py, vertices)
    local x1, y1, x2, y2, x3, y3 = vertices[1], vertices[2], vertices[3], vertices[4], vertices[5], vertices[6]
    local denom = ((y2 - y3)*(x1 - x3) + (x3 - x2)*(y1 - y3))
    local a = ((y2 - y3)*(px - x3) + (x3 - x2)*(py - y3)) / denom
    local b = ((y3 - y1)*(px - x3) + (x1 - x3)*(py - y3)) / denom
    local c = 1 - a - b
    return 0 <= a and a <= 1 and 0 <= b and b <= 1 and 0 <= c and c <= 1
end

function spawnExplosion(x, y, color)
    local ps = love.graphics.newParticleSystem(love.graphics.newImage('particle.png'), 100)
    ps:setParticleLifetime(0.5, 1)
    ps:setEmissionRate(100)
    ps:setSizeVariation(1)
    ps:setLinearAcceleration(-200, -200, 200, 200)
    ps:setColors(color[1], color[2], color[3], 1, color[1], color[2], color[3], 0)
    ps:setPosition(x, y)
    ps:emit(50)
    table.insert(particleSystems, ps)
    sounds.explosion:stop()
    sounds.explosion:play()
end

function spawnImpactEffect(x, y)
    local ps = love.graphics.newParticleSystem(love.graphics.newImage('particle.png'), 50)
    ps:setParticleLifetime(0.2, 0.5)
    ps:setEmissionRate(100)
    ps:setSizeVariation(1)
    ps:setLinearAcceleration(-100, -100, 100, 100)
    ps:setColors(1, 1, 0, 1, 1, 0, 0, 0)
    ps:setPosition(x, y)
    ps:emit(20)
    table.insert(particleSystems, ps)
end

function playDashEffect()
    local ps = love.graphics.newParticleSystem(love.graphics.newImage('particle.png'), 50)
    ps:setParticleLifetime(0.1, 0.2)
    ps:setEmissionRate(100)
    ps:setSizeVariation(1)
    ps:setSpeed(200)
    ps:setSpread(math.rad(360))
    ps:setColors(0.5, 0.5, 1, 1, 0.5, 0.5, 1, 0)
    ps:setPosition(player.x, player.y)
    ps:emit(30)
    table.insert(particleSystems, ps)
end

--............................................................| fin del código.
--Todos los derechos reservados a FECORO, 2023.