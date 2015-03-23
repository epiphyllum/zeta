----------------------------------------------------------
-- 节假日信息表
----------------------------------------------------------
-- year    : 年份
-- days    : 这年有多少天
-- holiday : 哪些天是放假 -  1,2,3...366
----------------------------------------------------------
drop table dict_holi;
create table dict_holi (
    year char(4),
    days integer,
    holiday varchar(2048)
);
create unique index idx_dict_holi on dict_holi(year);

