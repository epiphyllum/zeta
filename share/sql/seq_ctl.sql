-----------------------------------------------
-- 序列号生成器控制表
-----------------------------------------------
-- key    : 生成器名称
-- cur    : 当前可用序列好
-- min    : 最小序列号
-- max    : 最大序列号
-- ts_c   : 创建时间
-- ts_u   : 最近更新时间
-----------------------------------------------
drop table seq_ctl;
create table seq_ctl (
    key  char(8),
    cur  bigint,
    min  bigint,
    max  bigint,
    ts_c timestamp default current_timestamp,
    ts_u timestamp
);
create unique index idx_seq_ctl on seq_ctl(key);
