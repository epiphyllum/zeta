drop table fload;
create table fload(
    a  char(5),
    k1 integer,
    b  char(5),
    k2 integer,
    c  char(5),
    d  char(5),
   
    memo varchar(512),
    oid  char(8),
    ts_c timestamp default current_timestamp,
    ts_u timestamp
);
create unique index idx_fload on fload(k1, k2);

