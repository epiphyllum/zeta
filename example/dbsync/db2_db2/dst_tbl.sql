drop table dst_tbl;
create table dst_tbl (
    k12   int,
    u1    int,
    u2    int,
    u12   int,
    ts_u  timestamp
);
create unique index idx_dst_tbl on dst_tbl(k12);

