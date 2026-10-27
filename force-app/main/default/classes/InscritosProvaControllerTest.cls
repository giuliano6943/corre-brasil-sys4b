@IsTest
private class InscritosProvaControllerTest {

    private static Prova__c criarProva() {
        Datetime largada = Datetime.now().addDays(30);
        Prova__c prova = new Prova__c(
            Name = 'Prova Controller', Cidade__c = 'Sao Paulo', Regiao__c = 'Sudeste',
            Distancia__c = '5 KM', Vagas__c = 10, Taxa_de_Inscricao__c = 50,
            Data_e_Hora_da_Largada__c = largada, Situacao__c = 'Aberto',
            Local_retirada_Kit__c = 'Arena Teste',
            inicio_retirada_kit__c = largada.addDays(-4), fim_retirada_kit__c = largada.addDays(-1)
        );
        insert prova;
        return prova;
    }

    private static Corredor__c criarCorredor(String nome) {
        Corredor__c corredor = new Corredor__c(
            Name = nome, Email__c = 'teste@example.com',
            Celular__c = '(11) 90000-0000', CEP__c = '01001-000'
        );
        insert corredor;
        return corredor;
    }

    private static Inscricao__c montar(Id provaId, Id corredorId, String situacao) {
        return new Inscricao__c(Name = 'Inscricao teste', Prova__c = provaId,
            Corredor__c = corredorId, Situacao__c = situacao);
    }

    @IsTest
    static void devolveOsInscritosOrdenadosPorCorredor() {
        Prova__c prova = criarProva();
        Corredor__c ana = criarCorredor('Ana Teste');
        Corredor__c bruno = criarCorredor('Bruno Teste');
        insert new List<Inscricao__c>{
            montar(prova.Id, bruno.Id, 'Confirmada'),
            montar(prova.Id, ana.Id, 'Concluiu')
        };

        Test.startTest();
        List<InscritosProvaController.InscritoDto> lista = InscritosProvaController.getInscritos(prova.Id);
        Test.stopTest();

        System.assertEquals(2, lista.size(), 'Deveriam vir 2 inscritos');
        System.assertEquals('Ana Teste', lista[0].corredor, 'A lista vem em ordem alfabetica');
        System.assertEquals('Concluiu', lista[0].situacao, 'A situacao da Ana');
        System.assertEquals('Bruno Teste', lista[1].corredor, 'O segundo e o Bruno');
    }

    @IsTest
    static void provaSemInscricoesDevolveListaVazia() {
        Prova__c prova = criarProva();

        Test.startTest();
        List<InscritosProvaController.InscritoDto> lista = InscritosProvaController.getInscritos(prova.Id);
        Test.stopTest();

        System.assertEquals(0, lista.size(), 'Prova sem inscricoes devolve lista vazia, nao erro');
    }

    @IsTest
    static void usuarioSemAcessoRecebeMensagemAmigavel() {
        Prova__c prova = criarProva();
        Profile semAcesso = [SELECT Id FROM Profile WHERE Name = 'Chatter Free User' LIMIT 1];

        // Criar usuário é "setup"; dentro do runAs evita o erro de DML misto
        User usuario;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            usuario = new User(
                Alias = 'semacess', Email = 'sem.acesso@example.com', EmailEncodingKey = 'UTF-8',
                LastName = 'SemAcesso', LanguageLocaleKey = 'pt_BR', LocaleSidKey = 'pt_BR',
                ProfileId = semAcesso.Id, TimeZoneSidKey = 'America/Sao_Paulo',
                Username = 'sem.acesso.' + Datetime.now().getTime() + '@example.com'
            );
            insert usuario;
        }

        Boolean lancou = false;
        String mensagem;
        Test.startTest();
        System.runAs(usuario) {
            try {
                InscritosProvaController.getInscritos(prova.Id);
            } catch (AuraHandledException e) {
                lancou = true;
                mensagem = e.getMessage();
            }
        }
        Test.stopTest();

        System.assert(lancou, 'Sem acesso ao objeto, deveria lancar AuraHandledException');
        System.assertEquals('Não foi possível carregar as inscrições desta prova. Tente novamente em instantes.',
            mensagem, 'O usuario deve ver a mensagem amigavel, nao o erro tecnico');
    }
}