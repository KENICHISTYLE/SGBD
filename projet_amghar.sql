-----------------------------------------------------------------------------------------------
-- AMGHAR Nassim 
-- Groupe TP2
-- Banque 
-- Toutes les procedures et fonctions on ete ecrites par moi
-----------------------------------------------------------------------------------------------
-- les referance de la banque
-----------------------------------------------------------------------------------------------
 drop table refbanque ;
-- 

 create table refbanque(
	id_banque integer,
	taux float(2),
	constraint pk_banque primary key (id_banque)
	);

-----------------------------------------------------------------------------------------------
-- les client qui on un compte a la banque
-----------------------------------------------------------------------------------------------
 drop table client cascade constraints;
--

 create table client(
	id_client integer,-- /* id unique du client*/
	ou_client varchar2(12) not null,--/* user oracle*/ 
	etat integer,               -- /* soit 0 actif ou 1 bloque */
	solde integer,
	decouvert_autorise integer,	
	constraint pk_client primary key (id_client),
	constraint ch__etat check (etat = 1 or etat = 0), 
	constraint ch_solde_ check (solde >= decouvert_autorise),
	constraint ch_dec_autorise check (decouvert_autorise <= 0 and decouvert_autorise > -10000),	
	constraint un_ora_user unique (ou_client) 
 );


-----------------------------------------------------------------------------------------------
-- les virements d'un compte d'un compte d'une certaine banque vers un autre compte  
-- d'une banque qulconque
-----------------------------------------------------------------------------------------------
 drop table virements cascade constraints;
--
 drop sequence seq_id_virement;
 create sequence seq_id_virement;
--
 create table virements(
	id_virement integer,
	id_client_debiter integer,       /* c'est pas sur que les deux  */
	id_client_crediter integer,      /* comptes apartienne a notre  */				      
	id_banque_debiter integer,       /* banque, un des deux doit    */  
	id_banque_crediter integer,      /* l'etre                      */ 
	montant integer,
	etat_transaction number(1),        /* etat 0 echouer 1 reussi */
	date_du_vir date,
	constraint pk_id_virement primary key (id_virement),
	constraint ch_montant_virement check (montant > 0)
 );
--select id_client_debiter ,id_client_crediter,montant from virements;
-----------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------
---------------------------------- fonction et procedures -------------------------------------
-----------------------------------------------------------------------------------------------
-- ouverture de comptes
-----------------------------------------------------------------------------------------------
-- annexe qui renvoit vari si client deja inscrit  // fonctionne correctement
--
create or replace function deja_inscrit(id_user in integer) return boolean is
	id integer;
	dejainscrit exception;
	c sys_refcursor ;
	
begin
	open c for
		select id_client 
		from client ;	
	loop
	fetch c into id;	
	exit when c%notfound;
	if (id = id_user) then raise dejainscrit;
	end if;
	end loop;
	return false;  -- n'existe pas
	exception
		when dejainscrit then begin 
		-- dbms_output.put_line ' Deja inscrit ';
		return true; -- existe dans la base
		end;
end;
/

show errors;
-- ouvrirCompte(id_user : integer, uo_user : varchar2) -> boolean  // fonctionne correctement
-- 
create or replace function ouvrirCompte(id_user in integer, uo_user in varchar2) return boolean is		
	c sys_refcursor;	
	val integer;	
begin
	-- verifier autre banque ?
	if (deja_inscrit(id_user) )then 
		return false;		
	else	
	insert into client values (id_user,uo_user,0,2000,(-150));	
	return true; -- inscription reussi
	end if;
					
end;
/
show errors;
-----------------------------------------------------------------------------------------------
-- annexe virement possible  // fonctionne correctement
create or replace function virement_possible(id_user integer, montant integer) return boolean is
	e integer;
	s integer;
	d integer;
	c sys_refcursor;
	
begin
	open c for
		select etat,solde,decouvert_autorise 
		from client
 		where id_client = id_user;
	loop                               -- il devrait y 'avoir 1 ou 0 ligne j'ai oublier la syntaxe il faut reverifier
		fetch c into e,s,d;
		exit when c%notfound;
		if( e = 0 and ((s - montant) > d)) then return true ;
		end if;
	end loop;
	return false; -- le solde n'est pas suffisant
end;
/
show errors;
-- virement(id_acheteur : integer, id_vendeur : integer, id_banque_vendeur : integer, uo_banque_vendeur : varchar2, montant : integer, reference : integer) -> boolean
--
create or replace function virement(id_acheteur in integer, id_vendeur in integer, id_banque_vendeur in integer,
				 uo_banque_vendeur in varchar2, montant in integer, reference in integer) return boolean is

	idb integer;	
	incval integer;   -- valeur de l'id du virement pour l'historique
	query varchar2(200); -- executer la procedure de l'autre banque ou notifier	
	uo_v varchar2(12);   -- user oracle de l'entreprise vendeuse
	v integer;
begin
	incval := seq_id_virement.nextval;
	v := 0;
	select id_banque  -- recup id notre banque
	into idb
	from refbanque; 	
	------------------------------- debut du virement -----------------------------------
	if (id_banque_vendeur = idb) then 
		begin -- interne a la banque
		if(deja_inscrit(id_acheteur) and deja_inscrit(id_vendeur)) then 
			begin-- les deux sont inscrit 
						
			if (virement_possible ( id_acheteur,montant)) then
				begin
				-- le virement peut etre fait le solde du compte est suffisant
				-- /* action compte achteur*/									
				update client  -- on diminue le solde du compte de l'achteur
				set solde = solde - montant
				where id_client = id_acheteur;
				-- /* action compte vendeur */		
							
				update client  -- on augmante le solde du compte du vendeur
				set solde = solde + montant
				where id_client = id_vendeur;
				-- /* enregistrer l'historique*/
				
				insert into virements values (incval,id_acheteur,id_vendeur,idb,idb,montant,1,SYSDATE);
				
				-- /* notifier a e1 */
				-- recuperer le user oracle du vendeur
				dbms_output.put_line(' banque : '||id_vendeur);
				select ou_client
				into uo_v
				from client
				where id_client = id_vendeur;
				dbms_output.put_line(' banque : '||uo_v);
				virtax(id_acheteur,idb,montant);
				-- notification
				query := 'begin  '||uo_v||'.notifierVirement(:ida,:ref);  end;';
				execute immediate query using  in id_acheteur, in reference;
				return true ;-- effectue avec succes
				end;--#######  E2 -> E3
			else    begin
				-- virement impossible pb de solde ou blockage
				dbms_output.put_line (' virement impossible pb dans le compte ');
				return false; -- echec
				end;
			end if;
			end;
		else
			begin	-- un des deux n'est pas inscrit
			 dbms_output.put_line (' un acteur sans compte et non inscrit ');
			return false; --echec
			end;
		end if;
		end;
	else                              
		-- externe (interbanquaire)
		if(deja_inscrit(id_acheteur) and virement_possible(id_acheteur,montant)) then
			begin -- le virement va etre effectue 			
			-- /* appler resevoir virement de l'autre banque */	
			query := 'begin if ('||uo_banque_vendeur||'.recevoirVirement(:ida, :idba, :idv, :som, :ref)) then :val := 1; else :val := 0; end if; end;';
			--query := 'call '||uo_banque_vendeur||'.recevoirVirement(:ida, :idba, :idv, :som, :ref) into :sortie';
			execute immediate query using in id_acheteur, in idb , in id_vendeur, in montant, in reference, out v;
			-- /* boolean recuperer effectuer ou annuler le virement */
			if (v=1) then
				begin -- effectuer le debit de solde
				update client 
				set solde = solde - montant
				where id_client = id_acheteur;
				insert into virements values (incval,id_acheteur,id_vendeur,idb,id_banque_vendeur,montant,1,SYSDATE);
				virtax(id_acheteur,idb,montant);
				end;
			else 
				begin
				 -- inserer un virement echoue
				insert into virements values (incval,id_acheteur,id_vendeur,idb,id_banque_vendeur,montant,0,SYSDATE);
				return false; -- echec
				end;
			end if;
			return true ;-- effectue avec succes
			end;
		else 
			begin-- achteur non inscrit ou solde insuffisant ou compte blocker
			 dbms_output.put_line (' acheteur non inscrit ou pb dans le compte ');
			return false; --echec
			end;
		
		end if;
	end if;
		
end;
/

show errors;
-----------------------------------------------------------------------------------------------
-- recevoirVirement(id_acheteur : integer, id_banque_acheteur : integer, id_vendeur : integer, montant : integer, reference : integer) -> boolean
--
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
show errors;
-----------------------------------------------------------------------------------------------
-- historique(id_user : integer)
--
create or replace function historique(id_user  integer) return sys_refcursor is
	c sys_refcursor;
begin
	open c for
		select date_du_vir,montant
		from virements
		where id_client_debiter = id_user or id_client_crediter = id_user;
	return c;

end;
/ 

show errors;
---------------------------------------------------------------------------------------------
-- inscription cci
create or replace procedure inscription_cci (cci_uo varchar2, mon_uo varchar2) is
	sqlDyn varchar2(100);
	id_user integer;	
	str varchar2(12);
begin
	delete from refbanque;	
	delete from virements;	
	delete from client ;		
	str := 'bank';		
	sqlDyn := 'begin :ret := '||cci_uo||'.inscription(:user, :str) ; end;' ;
	execute immediate sqlDyn using out id_user, in mon_uo, in str ;
	insert into client values (id_user,mon_uo,0,2000,(-150));		
	insert into refbanque values (id_user,0.02);
	dbms_output.put_line(id_user);
end;
/

show errors;
--------------------------------------------------------------------------------------------
--- clotureCompte

create or replace procedure clotureCompte(uo_user varchar2) is 
	x integer;
begin
	select id_client into x from client where ou_client = uo_user;
	delete from virements where id_client_debiter = x or id_client_crediter = x;	
	delete from client where ou_client = uo_user ;
	
	
end;
/
show errors;
--------------------------------------------------------------------------------------------
--- getsSlde
create or replace procedure getSolde(uo varchar2)is
	s integer;
	sqlDyn varchar2(100);
	x integer;
			
begin	
	select solde into x from  client  where ou_client = uo;
	
	dbms_output.put_line (' Solde : '|| x);

end;
/ 
show errors;
-------------------------------------------------------------------------------------------
------fonctions pour les taxes 
------------------------------------------------------------------------------------------
---- tax prises lors du virement
create or replace procedure virtax(idc integer,monid integer, montant integer) is
	temp integer;
	s integer;
	t float(2);	
begin
	
	select taux into t from refbanque;
	temp := montant*t;
	if (temp < 1) then temp := 1; end if; 
	update client 
	set solde = solde - temp
	where id_client = idc;
	update client
	set solde = solde + temp
	where id_client = monid;
end;
/

show errors;
----- bonus donner au client quand il resoit de l'argent
create or replace procedure givtax(idc integer,monid integer,montant integer) is
	temp integer;
	s integer;
	t float(2);	
begin
	 
	select taux into t from refbanque;
	temp := montant*t;
	if (temp < 1) then temp := 1; end if; 
	if( s> 2000)then
		update client 
		set solde = solde + (temp/2)
		where id_client = idc;	
		update client 
		set solde = solde - (temp/2)
		where id_client = monid;		
	end if;
end;
/

show errors;
------------------------------------------------------------------------------------
-- grant des execute pour les fonctions
--
 grant execute on getSolde to public;
 grant execute on clotureCompte to public;
 
 grant execute on ouvrirCompte to public;	
 grant execute on virement to public;	
 grant execute on recevoirVirement to public;
 grant execute on historique to public;	

 set serveroutput on;

---------affichage locale
create or replace procedure get_info is

cursor c is
	select id_client,ou_client,solde, decouvert_autorise 
	from client;

cursor c2 is
	select id_client_debiter,id_client_crediter,montant 
	from virements;


begin
	dbms_output.put_line (' Comptes clients ');	
 	for x in c loop
	exit when c% Notfound;
	dbms_output.put_line (' Id : '||x.id_client||' user : '||x.ou_client||' solde : '||x.solde||' decouvert autorise :'||x.decouvert_autorise);
	end loop;

	dbms_output.put_line (' Historiques des virements ');		

	for x in c2 loop
	exit when c2% Notfound;
	dbms_output.put_line (' Client debiter: '||x.id_client_debiter||' Client crediter : '||x.id_client_crediter||' Montant : '||x.montant);
	end loop;
end;
/

-- fonction a executer lors du demarage
-- execute relsiba_a.desinscription('namghar_a');
-- execute inscription_cci ('relsiba_a', 'namghar_a');
-- select * from virements; 
-- select * from client; 
-- delete from refbanque;
-- select * from refbanque; 
-- delete from client ;	

