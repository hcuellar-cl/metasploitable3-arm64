-- phpMyAdmin SQL Dump
-- version 3.5.8
-- http://www.phpmyadmin.net
-- Host: 127.0.0.1
-- PHP Version: 5.4.5

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

DROP DATABASE IF EXISTS `payroll`;
CREATE DATABASE `payroll`;
USE `payroll`;

DROP TABLE IF EXISTS `users`;

CREATE TABLE `users` (
  `username` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `first_name` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_name` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `salary` int(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `users` (`username`, `first_name`, `last_name`, `password`, `salary`) VALUES
('leia_organa', 'Leia', 'Organa', 'help_me_obiwan', 9560),
('luke_skywalker', 'Luke', 'Skywalker', 'like_my_father_beforeme', 1080),
('han_solo', 'Han', 'Solo', 'nerf_herder', 1200),
('artoo_detoo', 'Artoo', 'Detoo', 'b00p_b33p', 22222),
('c_three_pio', 'C', 'Threepio', 'Pr0t0c07', 3200),
('ben_kenobi', 'Ben', 'Kenobi', 'thats_no_m00n', 10000),
('darth_vader', 'Darth', 'Vader', 'Dark_syD3', 6666),
('anakin_skywalker', 'Anakin', 'Skywalker', 'but_master:(', 1025),
('jarjar_binks', 'Jar-Jar', 'Binks', 'mesah_p@ssw0rd', 2048),
('lando_calrissian', 'Lando', 'Calrissian', '@dm1n1str8r', 40000),
('boba_fett', 'Boba', 'Fett', 'mandalorian1', 20000),
('jabba_hutt', 'Jaba', 'Hutt', 'my_kinda_skum', 65000),
('greedo', 'Greedo', 'Rodian', 'hanSh0tF1rst', 50000),
('chewbacca', 'Chewbacca', '', 'rwaaaaawr8', 4500),
('kylo_ren', 'Kylo', 'Ren', 'Daddy_Issues2', 6667);

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
