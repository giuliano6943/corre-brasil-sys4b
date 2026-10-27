public without sharing class OcupacaoProvaService {

    // Textos exatamente como estão nas listas de opções da org
    public static final String PROVA_ABERTO    = 'Aberto';
    public static final String PROVA_ULTIMAS   = 'Ultimas vagas';
    public static final String PROVA_ESGOTADA  = 'Esgotada';
    public static final String PROVA_CANCELADA = 'Cancelada';
    public static final String INSCRICAO_CANCELADA = 'Cancelada';

    // Regra do RN12: decide a situação da prova a partir das vagas e das ocupadas
    public static String calcularSituacao(Integer vagas, Integer ocupadas) {
        if (vagas == null || vagas <= 0) {
            throw new OcupacaoProvaException('Prova sem numero de vagas valido: ' + vagas);
        }
        Integer total = (ocupadas == null) ? 0 : ocupadas;

        if (total >= vagas) {
            return PROVA_ESGOTADA;
        }
        // 90% ou mais, calculado só com inteiros: total/vagas >= 0,9 equivale a total*10 >= vagas*9
        if (total * 10 >= vagas * 9) {
            return PROVA_ULTIMAS;
        }
        return PROVA_ABERTO;
    }

    // Conta as inscrições que ocupam vaga, de várias provas, com UMA única consulta
    public static Map<Id, Integer> contarOcupadas(Set<Id> provaIds) {
        Map<Id, Integer> ocupadas = new Map<Id, Integer>();
        if (provaIds == null || provaIds.isEmpty()) {
            return ocupadas;
        }
        // Toda prova começa com 0, porque a consulta agregada não devolve provas sem inscrição
        for (Id provaId : provaIds) {
            ocupadas.put(provaId, 0);
        }

        String cancelada = INSCRICAO_CANCELADA;
        for (AggregateResult ar : [
            SELECT Prova__c provaId, COUNT(Id) total
            FROM Inscricao__c
            WHERE Prova__c IN :provaIds
              AND Situacao__c != :cancelada
            GROUP BY Prova__c
        ]) {
            ocupadas.put((Id) ar.get('provaId'), (Integer) ar.get('total'));
        }
        return ocupadas;
    }

    // Parte 2 (antes de salvar): recusa as inscrições que não cabem na prova.
    // Recebe só as inscrições que VÃO ocupar vaga (o handler faz esse filtro).
    public static void validarCapacidade(List<Inscricao__c> candidatas) {
        Set<Id> provaIds = new Set<Id>();
        for (Inscricao__c insc : candidatas) {
            if (insc.Prova__c != null) {
                provaIds.add(insc.Prova__c);
            }
        }
        if (provaIds.isEmpty()) {
            return;
        }

        // Duas consultas no total, não importa quantas inscrições cheguem
        Map<Id, Prova__c> provas = new Map<Id, Prova__c>([
            SELECT Id, Vagas__c, Situacao__c
            FROM Prova__c
            WHERE Id IN :provaIds
        ]);
        Map<Id, Integer> ocupadas = contarOcupadas(provaIds);

        for (Inscricao__c insc : candidatas) {
            Prova__c prova = provas.get(insc.Prova__c);
            if (prova == null) {
                continue;
            }
            if (prova.Situacao__c == PROVA_CANCELADA) {
                insc.Prova__c.addError('Esta prova foi cancelada e não aceita novas inscrições.');
                continue;
            }
            Integer ocupadasAgora = ocupadas.get(prova.Id);
            if (ocupadasAgora >= prova.Vagas__c) {
                insc.Prova__c.addError('Não há vagas disponíveis: a prova está esgotada.');
            } else {
                // Esta inscrição cabe: conta ela para as próximas do mesmo lote
                ocupadas.put(prova.Id, ocupadasAgora + 1);
            }
        }
    }

        // Parte 3 (depois de salvar): recalcula a situação das provas afetadas
    public static void atualizarSituacoes(Set<Id> provaIds) {
        if (provaIds == null || provaIds.isEmpty()) {
            return;
        }
        Map<Id, Integer> ocupadas = contarOcupadas(provaIds);

        List<Prova__c> paraAtualizar = new List<Prova__c>();
        for (Prova__c prova : [
            SELECT Id, Vagas__c, Situacao__c
            FROM Prova__c
            WHERE Id IN :provaIds
        ]) {
            // Prova cancelada é situação final: o código nunca mexe nela
            if (prova.Situacao__c == PROVA_CANCELADA) {
                continue;
            }
            String nova = calcularSituacao(Integer.valueOf(prova.Vagas__c), ocupadas.get(prova.Id));
            // Só atualiza quem realmente mudou
            if (nova != prova.Situacao__c) {
                prova.Situacao__c = nova;
                paraAtualizar.add(prova);
            }
        }
        if (!paraAtualizar.isEmpty()) {
            update paraAtualizar;
        }
    }
}