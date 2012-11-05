set serveroutput on;

create or replace procedure notifierVirement(ida integer,referance integer) is
begin
dbms_output.put_line (' val :'||ida||' '||referance);
end;
/



declare
b boolean;
begin
--insert into refbanque values (19,0.02);
b := ouvrirCompte(30,'namghar_a');
getSolde('namghar_a');
b := virement(222,30, 30,'namghar_a',200,0 );
getSolde('namghar_a');
b := recevoirVirement(222, 30, 30,500,0 );
getSolde('bohho');
-- Desinscription('namghar_a');
--delete from refbanque;
--dbms_output.put_line (' '||b);
end;
/
