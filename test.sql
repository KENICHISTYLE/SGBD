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




