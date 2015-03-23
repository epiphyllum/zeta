drop table seq_ctl;
create table seq_ctl (
    key  char(8),
    cur  bigint,
    min  bigint, 
    max  bigint,
    ts_c timestamp default current_timestamp,
    ts_u timestamp
);

