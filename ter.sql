


create or replace function recevoirVirement(id_acheteur in integer, id_banque_acheteur in integer, 
		id_vendeur in integer, montant in integer, reference in integer) return boolean is
	idb integer;	
	solde_v integer;
	query varchar2(200);
	uo_v varchar2(12);
	incval integer;
begin
	incval := seq_id_virement.nextval;
	select id_banque  -- recup id notre banque
	into idb
	from refbanque; 
	if (deja_inscrit(id_vendeur)) then 
		begin 		
		select ou_client
		into uo_v
		from client
		where id_client = id_vendeur;						
		update client  -- on augmante le solde du compte du vendeur
		set solde = solde + montant
		where id_client = id_vendeur;	
		givtax(	id_vendeur,idb,montant);
		insert into virements values (incval,id_acheteur,id_vendeur,id_banque_acheteur,idb,montant,1,SYSDATE);		
		dbms_output.put_line(' uo vendeur '||uo_v|| '  ');
		query := 'begin  '||uo_v||'.notifierVirement(:ida,:ref);  end;';
		execute immediate query using  in id_acheteur, in reference;
		return true;
		end;
	else 
		begin
		insert into virements values (incval,id_acheteur,id_vendeur,id_banque_acheteur,idb,montant,0,SYSDATE);		
		return false;
		end;	
	end if;
end;
/
