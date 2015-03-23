drop table src_tbl ;
create table src_tbl (
    k1   int,
    k2   int,
    u1   int,
    u2   int,
    ts_u timestamp
);
create unique index idx_src_tbl on src_tbl(k1, k2);

