--QB--
ALTER TABLE `player_vehicles` 
ADD COLUMN IF NOT EXISTS `stored` tinyint(4) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `parking` varchar(60) DEFAULT 'Central Garage',
ADD COLUMN IF NOT EXISTS `nickname` varchar(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `impound` tinyint(4) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `impound_fee` int(11) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `impound_reason` text DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `impound_release_date` int(11) DEFAULT 0;

CREATE TABLE IF NOT EXISTS `private_garages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) NOT NULL,
  `name` varchar(60) NOT NULL,
  `coords` longtext NOT NULL,
  `spawnPoint` longtext NOT NULL,
  PRIMARY KEY (`id`)
);


--ESX--

ALTER TABLE `owned_vehicles` 
ADD COLUMN IF NOT EXISTS `parking` varchar(60) DEFAULT 'Central Garage',
ADD COLUMN IF NOT EXISTS `nickname` varchar(50) DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `impound` tinyint(4) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `impound_fee` int(11) DEFAULT 0,
ADD COLUMN IF NOT EXISTS `impound_reason` text DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `impound_release_date` int(11) DEFAULT 0;

CREATE TABLE IF NOT EXISTS `private_garages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(60) NOT NULL,
  `name` varchar(60) NOT NULL,
  `coords` longtext NOT NULL,
  `spawnPoint` longtext NOT NULL,
  PRIMARY KEY (`id`)
);


