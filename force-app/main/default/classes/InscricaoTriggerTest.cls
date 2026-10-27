@IsTest
private class InscricaoTriggerTest {

    // ---------- Fábrica de dados: se um campo obrigatório mudar, ajuste só aqui ----------
    private static Prova__c criarProva(Integer vagas) {
        Datetime largada = Datetime.now().addDays(30);
        Prova__c prova = new Prova__c(
            Name = 'Prova Teste ' + vagas,
            Cidade__c = 'Sao Paulo',
            Regiao__c = 'Sudeste',
            Distancia__c = '5 KM',
            Vagas__c = vagas,
            Taxa_de_Inscricao__c = 50,
            Data_e_Hora_da_Largada__c = largada,
            Situacao__c = 'Aberto',
            Local_retirada_Kit__c = 'Arena Teste',
            inicio_retirada_kit__c = largada.addDays(-4),
            fim_retirada_kit__c = largada.addDays(-1)
        );
        insert prova;
        return prova;
    }

    private static Corredor__c criarCorredor() {
        Corredor__c corredor = new Corredor__c(
            Name = 'Corredor Teste',
            Email__c = 'corredor.teste@example.com',
            Celular__c = '(11) 90000-0000',
            CEP__c = '01001-000'
        );
        insert corredor;
        return corredor;
    }

    private static List<Inscricao__c> montarInscricoes(Id provaId, Id corredorId, Integer quantidade, String situacao) {
        List<Inscricao__c> lista = new List<Inscricao__c>();
        for (Integer i = 0; i < quantidade; i++) {
            lista.add(new Inscricao__c(
                Name = 'Inscricao teste',
                Prova__c = provaId,
                Corredor__c = corredorId,
                Situacao__c = situacao
            ));
        }
        return lista;
    }

    private static String situacaoDa(Id provaId) {
        return [SELECT Situacao__c FROM Prova__c WHERE Id = :provaId].Situacao__c;
    }

    // Muda só a situação, como a tela faz: manda apenas os campos alterados
    private static Database.SaveResult mudarSituacao(Id inscricaoId, String situacao, String motivo) {
        Inscricao__c alteracao = new Inscricao__c(Id = inscricaoId, Situacao__c = situacao);
        if (motivo != null) {
            alteracao.Motivo_do_Cancelamento__c = motivo;
        }
        return Database.update(alteracao, false);
    }

    // ---------- Teste 1: cenário positivo ----------
    @IsTest
    static void inscricaoQueCabeEGravadaEAProvaContinuaAberta() {
        Prova__c prova = criarProva(10);
        Corredor__c corredor = criarCorredor();

        Test.startTest();
        Database.SaveResult resultado = Database.insert(
            montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada')[0], false);
        Test.stopTest();

        System.assert(resultado.isSuccess(), 'A inscricao deveria ter sido gravada');
        System.assertEquals(1, [SELECT COUNT() FROM Inscricao__c WHERE Prova__c = :prova.Id],
            'Deveria existir 1 inscricao na prova');
        System.assertEquals('Aberto', situacaoDa(prova.Id), '1 de 10 vagas nao muda a situacao');
    }

    // ---------- Teste 2: fronteiras dos 90% e dos 100% ----------
    @IsTest
    static void situacaoAcompanhaAsFronteirasDeNoventaECemPorCento() {
        Prova__c prova = criarProva(10);
        Corredor__c corredor = criarCorredor();

        Test.startTest();
        insert montarInscricoes(prova.Id, corredor.Id, 8, 'Confirmada');
        System.assertEquals('Aberto', situacaoDa(prova.Id), '8 de 10 (80%) continua Aberto');

        insert montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada');
        System.assertEquals('Ultimas vagas', situacaoDa(prova.Id), '9 de 10 (90%) vira Ultimas vagas');

        insert montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada');
        System.assertEquals('Esgotada', situacaoDa(prova.Id), '10 de 10 (100%) vira Esgotada');
        Test.stopTest();
    }

    // ---------- Teste 3: lote de 200 (o caso do PDF) ----------
    @IsTest
    static void loteDeDuzentasInscricoesAceitaSoAsQueCabem() {
        Prova__c prova = criarProva(150);
        Corredor__c corredor = criarCorredor();
        List<Inscricao__c> lote = montarInscricoes(prova.Id, corredor.Id, 200, 'Confirmada');

        Test.startTest();
        Database.SaveResult[] resultados = Database.insert(lote, false);
        Integer consultas = Limits.getQueries();
        Test.stopTest();

        Integer gravadas = 0;
        Integer recusadas = 0;
        for (Database.SaveResult r : resultados) {
            if (r.isSuccess()) { gravadas++; } else { recusadas++; }
        }
        System.assertEquals(150, gravadas, 'Deveriam caber 150 inscricoes');
        System.assertEquals(50, recusadas, 'As outras 50 deveriam ser recusadas');
        System.assertEquals(150, [SELECT COUNT() FROM Inscricao__c WHERE Prova__c = :prova.Id],
            'So 150 inscricoes ficam no banco');
        System.assertEquals('Esgotada', situacaoDa(prova.Id), 'A prova deve terminar Esgotada');
        System.assert(consultas < 100, 'O lote nao pode gastar uma consulta por registro: ' + consultas);
    }

    // ---------- Teste 4: cenário negativo, prova esgotada ----------
    @IsTest
    static void inscricaoEmProvaEsgotadaERecusadaComMensagem() {
        Prova__c prova = criarProva(2);
        Corredor__c corredor = criarCorredor();
        insert montarInscricoes(prova.Id, corredor.Id, 2, 'Confirmada');

        Test.startTest();
        Database.SaveResult resultado = Database.insert(
            montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada')[0], false);
        Test.stopTest();

        System.assert(!resultado.isSuccess(), 'A terceira inscricao deveria ser recusada');
        System.assert(resultado.getErrors()[0].getMessage().contains('esgotada'),
            'A mensagem deveria falar de prova esgotada: ' + resultado.getErrors()[0].getMessage());
        System.assertEquals(2, [SELECT COUNT() FROM Inscricao__c WHERE Prova__c = :prova.Id],
            'Continuam so 2 inscricoes');
    }

    // ---------- Teste 5: cancelar libera vaga, reativar exige que caiba (before update) ----------
    @IsTest
    static void cancelarLiberaVagaEReativarExigeQueCaiba() {
        Prova__c prova = criarProva(2);
        Corredor__c corredor = criarCorredor();
        List<Inscricao__c> duas = montarInscricoes(prova.Id, corredor.Id, 2, 'Confirmada');
        insert duas;
        System.assertEquals('Esgotada', situacaoDa(prova.Id), '2 de 2 esgota a prova');

        Test.startTest();
        System.assert(mudarSituacao(duas[0].Id, 'Cancelada', 'Outros').isSuccess(),
            'Cancelar uma inscricao deveria funcionar');
        System.assertEquals('Aberto', situacaoDa(prova.Id), 'Cancelar libera: 1 de 2 (50%) volta a Aberto');

        insert montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada');
        System.assertEquals('Esgotada', situacaoDa(prova.Id), 'A vaga liberada foi ocupada de novo');

        Database.SaveResult reativacao = mudarSituacao(duas[0].Id, 'Confirmada', null);
        Test.stopTest();

        System.assert(!reativacao.isSuccess(), 'Reativar numa prova cheia deveria ser recusado');
        System.assert(reativacao.getErrors()[0].getMessage().contains('esgotada'),
            'Deveria ser recusada por falta de vaga: ' + reativacao.getErrors()[0].getMessage());
        System.assertEquals('Cancelada', [SELECT Situacao__c FROM Inscricao__c WHERE Id = :duas[0].Id].Situacao__c,
            'A inscricao continua cancelada');
    }

    // ---------- Teste 6: prova Cancelada não recebe inscrição e nunca volta a abrir ----------
    @IsTest
    static void provaCanceladaNaoRecebeInscricaoENuncaVoltaAAbrir() {
        Prova__c prova = criarProva(5);
        Corredor__c corredor = criarCorredor();
        Inscricao__c existente = montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada')[0];
        insert existente;

        prova.Situacao__c = 'Cancelada';
        update prova;

        Test.startTest();
        Database.SaveResult nova = Database.insert(
            montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada')[0], false);
        System.assert(mudarSituacao(existente.Id, 'Cancelada', 'Outros').isSuccess(),
            'Cancelar a inscricao existente deveria funcionar');
        Test.stopTest();

        System.assert(!nova.isSuccess(), 'Prova cancelada nao deveria aceitar inscricao nova');
        System.assert(nova.getErrors()[0].getMessage().contains('cancelada'),
            'A mensagem deveria falar de prova cancelada: ' + nova.getErrors()[0].getMessage());
        System.assertEquals('Cancelada', situacaoDa(prova.Id), 'Cancelada nunca volta para Aberto');
    }

    // ---------- Teste 7: excluir libera a vaga e restaurar ocupa de novo ----------
    @IsTest
    static void excluirLiberaVagaERestaurarOcupaDeNovo() {
        Prova__c prova = criarProva(2);
        Corredor__c corredor = criarCorredor();
        List<Inscricao__c> duas = montarInscricoes(prova.Id, corredor.Id, 2, 'Confirmada');
        insert duas;

        Test.startTest();
        delete duas[0];
        System.assertEquals('Aberto', situacaoDa(prova.Id), 'Excluir libera a vaga');
        undelete duas[0];
        Test.stopTest();

        System.assertEquals('Esgotada', situacaoDa(prova.Id), 'Restaurar ocupa a vaga de novo');
    }

    // ---------- Teste 8: excluir a prova (exclusão em cascata) ----------
    @IsTest
    static void excluirProvaApagaAsInscricoesSemErro() {
        Prova__c prova = criarProva(3);
        Corredor__c corredor = criarCorredor();
        insert montarInscricoes(prova.Id, corredor.Id, 2, 'Confirmada');

        Test.startTest();
        Database.DeleteResult resultado = Database.delete(prova, false);
        Test.stopTest();

        System.assert(resultado.isSuccess(), 'Excluir a prova nao deveria falhar: '
            + (resultado.isSuccess() ? '' : resultado.getErrors()[0].getMessage()));
        System.assertEquals(0, [SELECT COUNT() FROM Inscricao__c WHERE Prova__c = :prova.Id],
            'As inscricoes saem junto com a prova');
    }

    // ---------- Teste 9: duas provas no mesmo lote ----------
    @IsTest
    static void duasProvasNoMesmoLoteSaoContadasSeparadamente() {
        Prova__c pequena = criarProva(2);
        Prova__c grande = criarProva(10);
        Corredor__c corredor = criarCorredor();
        List<Inscricao__c> lote = new List<Inscricao__c>();
        lote.addAll(montarInscricoes(pequena.Id, corredor.Id, 3, 'Confirmada'));
        lote.addAll(montarInscricoes(grande.Id, corredor.Id, 3, 'Confirmada'));

        Test.startTest();
        Database.insert(lote, false);
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Inscricao__c WHERE Prova__c = :pequena.Id], 'A pequena aceita 2');
        System.assertEquals(3, [SELECT COUNT() FROM Inscricao__c WHERE Prova__c = :grande.Id], 'A grande aceita as 3');
        System.assertEquals('Esgotada', situacaoDa(pequena.Id), 'Pequena esgotada');
        System.assertEquals('Aberto', situacaoDa(grande.Id), 'Grande continua Aberta (3 de 10)');
    }

    // ---------- Teste 10: casos de borda do serviço ----------
    @IsTest
    static void casosDeBordaDoServico() {
        try {
            OcupacaoProvaService.calcularSituacao(0, 0);
            System.assert(false, 'Deveria ter lancado a excecao');
        } catch (OcupacaoProvaException e) {
            System.assert(e.getMessage().contains('vagas'), 'Mensagem inesperada: ' + e.getMessage());
        }

        System.assert(OcupacaoProvaService.contarOcupadas(new Set<Id>()).isEmpty(), 'Sem provas, mapa vazio');
        OcupacaoProvaService.atualizarSituacoes(null);

        Prova__c prova = criarProva(1);
        Corredor__c corredor = criarCorredor();
        insert montarInscricoes(prova.Id, corredor.Id, 1, 'Confirmada');
        Inscricao__c nasceCancelada = montarInscricoes(prova.Id, corredor.Id, 1, 'Cancelada')[0];
        nasceCancelada.Motivo_do_Cancelamento__c = 'Outros';
        Database.SaveResult resultado = Database.insert(nasceCancelada, false);
        System.assert(resultado.isSuccess(), 'Inscricao que ja nasce Cancelada nao ocupa vaga');
    }
}